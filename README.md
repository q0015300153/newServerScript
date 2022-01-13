# 自動化架站腳本

### 以 sudo 權限執行
```bash
sudo sh ./ec2-new-buuntu.sh
```
### 腳本內有參數，請依照專案與環境修改

> 此腳本會安裝 nginx + php + mariadb 在 ubuntu 上
> 
> 並設定資料庫使用者 + nginx 網站設定檔

> 如果在虛擬機測試記得不要開啟安裝免費 SSL 證書，
> 
> 會驗證不過

> 如果使用 RDS 不用安裝資料庫

> 附有 index.php 用以驗證架設成功
> 
> 以 adminer.php 連接資料庫 (如果有安裝資料庫的話)
