Start your mongodb server with automatic restore from S3 at startup and backup to S3

# How to run ?

Prerequisites : Dont't forget to configure your environment variables in `docker-compose.yaml`
- `DATABASES` Name of the databases to backup/restore
- `BUCKET` Name of the S3 bucket to store backups
- `AWS_ACCESS_KEY_ID` Your AWS Access Key ID
- `AWS_SECRET_ACCESS_KEY` Your AWS Secret Key
- `INTERVAL` Backup interval in second (default: 300 - 5 minutes)

Simply run `docker-compose up`, your mongodb server will start as well as the backup and restore service

# Manually run the backup / restore scripts

- Restore : `docker-compose exec backup sh /restore.sh <database_name>`
- Backup : `docker-compose exec backup sh /backup.sh <database_name>`