#! /bin/bash
function foobar {
    for i in *.org ; do
        b=$(echo $i | sed 's/\.org//')
        o=../html/$b.html
        echo $b # $i $o
        pandoc \
            --standalone \
            --include-in-header=../include/header.html \
            --include-before-body=../include/before-body.html \
            --include-after-body=../include/after-body.html \
            --from=org+smart --to=html5 -o $o \
            <(cat $i | sed 's/\.org/.html/g')
    done
}

( cd ~/u/proj/recipe && mkdir -p org )
( cd ~/u/proj/recipe && mkdir -p html )
/bin/rm -rf ~/u/proj/recipe/org/*.org
/bin/rm -rf ~/u/proj/recipe/html/*.html
emacs \
  --no-init-file --batch \
  --load ~/u/proj/recipe/recipes.el --funcall wja/export-recipe-list  2>&1
( cd ~/u/proj/recipe/org && foobar )
cp -ip \
   ~/u/proj/recipe/html/0-recipe-index.html \
   ~/u/proj/recipe/html/index.html
rsync -avz --delete ~/u/proj/recipe/html/ hep:public_html/recipe/ 
