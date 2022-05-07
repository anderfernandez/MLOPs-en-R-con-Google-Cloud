git config --global user.name 'Ander Fernández'
git config --global user.email 'anderfernandezj@gmail.com'
git add .
set +e 
git status | grep modified
if [ $? -eq 0 ]
then
    set -e
    git commit -am "Automatically updated"
    git push
else
    set -e
    echo "No changes since last run"
fi