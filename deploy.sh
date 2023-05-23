npm run build
ssh root@39.98.62.127 "rm /home/tj/dnmp/www/wiki-honlyc/* -rf"
scp -r build/* root@39.98.62.127:/home/tj/dnmp/www/wiki-honlyc/

git add -A
# Commit changes.
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"

git push