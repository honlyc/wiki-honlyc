npm run build
ssh root@39.98.62.127 "rm /home/tj/dnmp/www/wiki-honlyc/* -rf"
scp -r build/* root@39.98.62.127:/home/tj/dnmp/www/wiki-honlyc/