# Hướng Dẫn Deploy Dự Án Laravel Lên AWS EC2

## Giới thiệu

Tài liệu này cung cấp hướng dẫn chi tiết để triển khai một dự án Laravel lên môi trường AWS, sử dụng EC2 (CentOS), ALB, Route53, và ACM với các công nghệ như Nginx, Git, Supervisor, PHP 8.2 (thay bằng phiên bản PHP tuỳ chọn), Composer, và Crontab.

## Chuẩn bị

### Yêu cầu trước khi bắt đầu:
- Một tài khoản AWS đã được kích hoạt
- Dự án Laravel đã sẵn sàng để triển khai (có repository Git)
- Một tên miền đã đăng ký (sẽ được sử dụng với Route53)
- Hiểu biết cơ bản về Linux và dòng lệnh

### Các thành phần sẽ sử dụng:
- **EC2**: Máy chủ ảo chạy CentOS
- **ALB (Application Load Balancer)**: Cân bằng tải và phân phối lưu lượng
- **Route53**: Dịch vụ DNS để quản lý tên miền
- **ACM (AWS Certificate Manager)**: Quản lý chứng chỉ SSL/TLS
- **Nginx**: Máy chủ web
- **PHP 8.2**: Môi trường chạy mã PHP
- **Composer**: Công cụ quản lý gói cho PHP
- **Git**: Hệ thống quản lý phiên bản
- **Supervisor**: Quản lý các tiến trình
- **Crontab**: Lập lịch các tác vụ tự động

## Cài đặt môi trường trên EC2

### 1. Kết nối SSH vào EC2 instance:

```bash
ssh -i /đường/dẫn/tới/key.pem ec2-user@địa_chỉ_ip_public
```

### 2. Cập nhật hệ thống:

```bash
sudo yum update -y
```

### 3. Cài đặt các gói cơ bản:

```bash
sudo yum install -y git wget unzip
```

### 4. Cài đặt Nginx:

```bash
sudo yum install -y epel-release
sudo yum install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 5. Cài đặt PHP 8.2 và các extension cần thiết:

```bash
# Cài đặt Remi repository
sudo yum install -y dnf-utils http://rpms.remirepo.net/enterprise/remi-release-8.rpm

# Kích hoạt PHP 8.2
sudo dnf module reset php -y
sudo dnf module enable php:remi-8.2 -y

# Cài đặt PHP và các extension
sudo dnf install -y php php-cli php-fpm php-mysqlnd php-zip php-devel php-gd php-mcrypt php-mbstring php-curl php-xml php-pear php-bcmath php-json php-redis php-opcache

# Khởi động PHP-FPM
sudo systemctl start php-fpm
sudo systemctl enable php-fpm
```

### 6. Cài đặt Composer:

```bash
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
sudo chmod +x /usr/local/bin/composer
```

### 7. Cài đặt Supervisor:

```bash
sudo yum install -y supervisor
sudo systemctl start supervisord
sudo systemctl enable supervisord
```

## Triển khai dự án Laravel

### 1. Clone dự án từ Git repository:

```bash
cd /home/admin
git clone [đường-dẫn-git-repository] .
```

### 2. Cài đặt các package phụ thuộc:

```bash
composer install
```

### 3. Cấu hình môi trường Laravel:

```bash
cp .env.example .env
php artisan key:generate
```

### 4. Chỉnh sửa file .env:

```bash
nano .env
```

Thay đổi các cấu hình sau:
```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://tên-miền-của-bạn.com

DB_HOST=endpoint-của-rds-hoặc-địa-chỉ-database
DB_DATABASE=tên_database
DB_USERNAME=tên_người_dùng
DB_PASSWORD=mật_khẩu

CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_DRIVER=database
```

### 6. Thiết lập quyền để Nginx có thể truy cập vào các file và thư mục:

```bash
sudo chown -R nginx:nginx /home/admin/project-sample
sudo find /home/admin/project-sample/storage -type d -exec chmod 775 {} \;
sudo find /home/admin/project-sample/storage -type f -exec chmod 664 {} \;
```

### 7. Tối ưu hóa Laravel cho production (mỗi lần release phải chạy lại):

```bash
php artisan optimize
```

## Cấu hình Nginx

### 1. Tạo file cấu hình Nginx cho dự án:

```bash
sudo nano /etc/nginx/conf.d/[tên-dự-án].conf
```

### 2. Thêm nội dung cấu hình sau:

```nginx
server {
    listen 80;
    server_name tên-miền-của-bạn.com www.tên-miền-của-bạn.com;
    root /home/admin/project-sample/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php-fpm/www.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

### 3. Kiểm tra và khởi động lại Nginx:

```bash
sudo nginx -t
sudo systemctl restart nginx
```

## Cấu hình SSL với ACM

### 1. Tạo chứng chỉ SSL trong ACM:

1. Truy cập AWS Certificate Manager trong Console
2. Nhấp vào "Request a certificate"
3. Chọn "Request a public certificate" và nhấp "Next"
4. Nhập tên miền (tên-miền-của-bạn.com và www.tên-miền-của-bạn.com)
5. Chọn phương thức xác minh (khuyến nghị: DNS validation)
6. Nhấp vào "Request"

### 2. Xác minh quyền sở hữu tên miền:

Nếu sử dụng Route53, bạn có thể nhấp vào "Create record in Route53" để tự động thêm bản ghi DNS.

Nếu không sử dụng Route53, bạn cần tạo bản ghi CNAME trong DNS provider.

### 3. Đợi xác minh hoàn tất (có thể mất vài phút hoặc hơn)

## Thiết lập Load Balancer (ALB)

### 1. Tạo Target Group:

1. Truy cập EC2 > Target Groups
2. Nhấp vào "Create target group"
3. Cấu hình:
   - **Target type**: Instances
   - **Name**: [tên-dự-án]-tg
   - **Protocol**: HTTP
   - **Port**: 80
   - **VPC**: Chọn VPC của bạn
   - **Health check settings**: Path: `/` (hoặc endpoint health check thích hợp)
4. Nhấp "Next"
5. Chọn EC2 instance và nhấp "Include as pending below"
6. Nhấp "Create target group"

### 2. Tạo Application Load Balancer (Nếu chưa có)

1. Truy cập EC2 > Load Balancers
2. Nhấp vào "Create Load Balancer"
3. Chọn "Application Load Balancer"
4. Cấu hình cơ bản:
   - **Name**: [tên-dự-án]-alb
   - **Scheme**: Internet-facing
   - **IP address type**: IPv4
5. Network mapping:
   - Chọn VPC của bạn
   - Chọn ít nhất 2 Availability Zones và subnet public
6. Security groups:
   - Tạo hoặc chọn security group cho phép HTTP (80) và HTTPS (443)
7. Listeners:
   - HTTP (80): Forward to [tên-dự-án]-tg
   - HTTPS (443): Forward to [tên-dự-án]-tg
   - Chọn chứng chỉ SSL đã tạo từ ACM
8. Nhấp "Create load balancer"

### 3. Cấu hình chuyển hướng HTTP sang HTTPS:

1. Chọn ALB vừa tạo
2. Chọn tab "Listeners"
3. Chọn HTTP:80 và nhấp "Edit"
4. Thay đổi action thành "Redirect to HTTPS:443"
5. Nhấp "Update"

## Cấu hình Route53

### 1. Tạo Hosted Zone (nếu chưa có):

1. Truy cập Route53 > Hosted zones
2. Nhấp vào "Create hosted zone"
3. Nhập tên miền của bạn
4. Kiểu: Public hosted zone
5. Nhấp "Create"

### 2. Cập nhật Name Servers:

Cập nhật name servers ở nơi đăng ký tên miền với các name servers được AWS cung cấp.

### 3. Tạo bản ghi A để trỏ đến ALB:

1. Trong hosted zone của bạn, nhấp "Create record"
2. Cấu hình:
   - **Record name**: Để trống (apex domain) hoặc www
   - **Record type**: A
   - **Alias**: Yes
   - **Route traffic to**: Application and Classic Load Balancer
   - Chọn region và ALB của bạn
3. Nhấp "Create records"

### 4. Tạo bản ghi www (nếu cần):

Lặp lại các bước trên để tạo bản ghi A cho www.tên-miền-của-bạn.com

## Cấu hình Supervisor

### 1. Tạo thư mục cấu hình cho Supervisor:

```bash
sudo mkdir -p /etc/supervisor/conf.d/
```

### 2. Tạo file cấu hình cho Laravel Queue Worker:

```bash
sudo nano /etc/supervisor/conf.d/laravel-worker.conf
```

### 3. Thêm nội dung cấu hình:

```ini
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/[tên-dự-án]/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=ec2-user
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/[tên-dự-án]/storage/logs/worker.log
stopwaitsecs=3600
```

### 4. Cập nhật và khởi động lại Supervisor:

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start all
```

## Thiết lập Crontab

### 1. Mở crontab cho người dùng ec2-user:

```bash
crontab -e -u apache
```

### 2. Thêm lịch cho Laravel scheduler:

```
* * * * * cd /home/admin/project-sample && php artisan schedule:run >> /dev/null 2>&1
```

## Kiểm tra và theo dõi

### 1. Kiểm tra ứng dụng Laravel:

Truy cập tên miền của bạn trong trình duyệt để đảm bảo mọi thứ hoạt động.

### 2. Kiểm tra logs:

```bash
# Nginx logs
sudo tail -f /var/log/nginx/error.log

# Laravel logs
tail -f /home/admin/project-sample/storage/logs/laravel.log
```