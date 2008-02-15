require 'nginxr'

conf = Nginx::Config.new('/etc/nginx/nginx.conf') do

  user  "www-data"
  worker_processes  6
  worker_rlimit_nofile 10240
  error_log "/var/log/nginx/error.log", :warn

  events do
    use :epoll
    worker_connections 16384
  end

  http do
    _include "/etc/nginx/mime.types"
    default_type "application/octet-stream"
    log_format :main, '$remote_addr - - [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"'
    log_format :combined, '$remote_addr - - [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" "$http_host" $request_time "$http_x_forwarded_for" "$http_via" "$gzip_ratio"'
    access_log "/var/log/nginx/access.log", :combined

    sendfile        :on
    keepalive_timeout  65

    upload_progress :proxied, '1m'

    upstream :localbackends do
      server "127.0.0.1:8003", :max_fails => 3, :fail_timeout => '30s'
      server "127.0.0.1:8004", :max_fails => 3, :fail_timeout => '30s'
    end
    upstream :counters do
      server "127.0.0.1:8001", :max_fails => 3, :fail_timeout => '30s'
      server "127.0.0.1:8002", :max_fails => 3, :fail_timeout => '30s'
    end
    upstream :localproxies do
      3.times do |i|
        server "v00#{i}:8888", :weight => 15, :max_fails => 3, :fail_timeout => '30s'
      end
    end
  
    # dynamic pages
    server do
      listen 8888
      client_max_body_size "50m"
      # Switch the log off, logging is done on a very frontend (port 80)
      access_log :off
      location '/' do
        # matches any query, since all queries begin with /, but regular
        # expressions and any longer conventional blocks will be
        # matched first.
        configuration :A
        proxy_set_header 'Host', '$http_host'
        proxy_set_header 'X-Real-IP', '$remote_addr'
        proxy_set_header 'X-Forwarded-For', '$proxy_add_x_forwarded_for'
        proxy_pass 'http://localbackends'
      end
      location '/', :strict do
        # matches the query / only.
        configuration :B
      end
      location '/images/', :no_regexps do
        # matches any query beginning with /images/ and halts searching,
        # so regular expressions will not be checked.
        configuration :C
      end
      location %r{\.(gif|jpg|jpeg)$}i do
        # matches any request ending in gif, jpg, or jpeg. However, all
        # requests to the /images/ directory will be handled by
        # Configuration C.   
        configuration :D
      end
    end
  
    server do
      listen  80
      charset :off

      client_max_body_size    '1000m'
      client_body_buffer_size '1m'
      client_body_temp_path   '/tmp/nginx.client_body_temp'

      root        '/var/www/rails/public'
      error_page  413, '/413.html'
      error_page  404, '/404.html'
    
      # This returns JSON status (supply ?X-Progress-ID=......)
      location '/videos/upload-progress', :no_regexps do
        # report uploads tracked in the 'proxied' zone
        report_uploads :proxied
      end
    
      # redirectors
      location '/get_video' do
        proxy_pass 'http://redirectors'
      end
      location '/get_thumbnail' do
        proxy_pass 'http://redirectors'
      end
    
      # dynamic pages
      location '/' do
        gzip  :on;
        proxy_set_header 'Host', '$http_host'
        proxy_set_header 'X-Real-IP', '$remote_addr'
        proxy_set_header 'X-Forwarded-For', '$proxy_add_x_forwarded_for'
        proxy_pass 'http://localproxies'
      end
      
      _if '$slow' do
        limit_rate '10k'
    #    break
      end

      rewrite %r{^/assets/([^/]+/[0123].+)$}, '/assets/partition_1/$1' 
      rewrite %r{^/assets/([^/]+/[4567].+)$}, '/assets/partition_2/$1'
      rewrite %r{^/assets/([^/]+/[89ab].+)$}, '/assets/partition_3/$1'
      rewrite %r{^/assets/([^/]+/[cdef].+)$}, '/assets/partition_4/$1', :last

      # Give FLV or (if not found) "in process" lounge video
      location %r{/assets.*\.flv$} do
        set '$limit_rate', '128k'
        root '/var/www'
        flv
        access_log :off
        _if %(!-f $request_filename) do
          root    '/var/www/rails/public'
          expires 0
          add_header 'Cache-Control', 'no-cache'
          rewrite %r/^.*$/, '/in_process.flv', :break
        end
      end
    end
  end
end

# Output generated config
puts conf.body
