(defun wja/export-recipe-list ()
  "convert proj/recipe/recipes.org into contents of proj/recipe/org/"
  (save-current-buffer  ;; this may not be needed
    ;; read in master list of recipes (org-mode format)
    (find-file-read-only "~/u/proj/recipe/recipes.org")
    ;; clear out contents of output folder
    (shell-command-to-string "/bin/rm -f ~/u/proj/recipe/org/*.org")
    (let (recipelist alltags tag dum recipe)  ;; local variables
      ;; along the way, we will build up a master list of recipes
      (setq recipelist nil)
      ;; loop over all "sections" of text that live beneath headlines;
      ;; each such section (under a level-3 headline) is a recipe
      (org-element-map
          ;; parse buffer to find all headlines; the abstract syntax
          ;; tree will also include the "sections" of text that are
          ;; the headlines' contents
          (org-element-parse-buffer 'headlines)
          'section
        (lambda (section)  ;; apply this code to each section
          ;; recipes.org should be organized such that
          ;; - each recipe is a level-3 headline
          ;; - each level-2 headline is a category of recipes,
          ;;   whose tags should be inherited by its children
          (let (begin end parent grandparent tags title fnam bigbuf)
            ;; the recipes.org buffer
            (setq bigbuf (current-buffer))
            ;; the beginning and ending character positions of this
            ;; recipe within the recipes.org buffer
            (setq begin (org-element-property :contents-begin section))
            (setq end (org-element-property :contents-end section))
            ;; the containing headlines (L3 and L2) for this recipe
            (setq parent (org-element-property :parent section))
            (setq grandparent (org-element-property :parent parent))
            ;; the list of tags (categories of recipe) with which
            ;; this recipe has been labeled
            (setq tags (append (org-element-property :tags grandparent)
                               (org-element-property :tags parent)))
            (setq tags (sort (delete-dups tags) 'string-lessp))
            ;; only "sections" that live directly below level-3 headlines
            ;; can be recipes; this code assumes that structure
            (when (equal 3 (org-element-property :level parent))
              ;; title of this recipe
              (setq title (org-element-property :title parent))
              ;; make a nice filename from title
              (setq fnam (replace-regexp-in-string
                          "[^a-z0-9]+" "-" (downcase title)))
              ;; debug print
              (princ (format "[%d,%d] %S %S %S\n" begin end title fnam tags))
              ;; build up an elisp "property list" for this recipe
              (setq recipe
                    (list :fnam fnam :title title :tags tags))
              ;; insert this recipe at front of big recipe list
              (setq recipelist (cons recipe recipelist))
              ;; add on the ugly parts of the filename
              (setq fnam (concat "~/u/proj/recipe/org/r-" fnam ".org"))
              ;; write out an individual .org file for this recipe
              (with-temp-buffer
                (insert (format "#+pagetitle: %s\n\n" title))
                ;; level-2 headline for recipe title
                (insert (format "** %s\n\n" title))
                ;; link back to master list
                (insert "  [[[file:0-recipe-index.org][main recipe page]]]\n\n")
                ;; list this recipe's categories, if any
                (when tags
                  (if (equal 1 (length tags))
                      ;; exacty one category tag
                      (insert (format "category: [[[file:c-%s.org][%s]]]\n\n"
                                      (nth 0 tags) (nth 0 tags)))
                    ;; more than one category tag
                    (insert (format "categories:"))
                    (dolist (tag tags)
                      (insert (format " [[[file:c-%s.org][%s]]]" tag tag)))
                    (insert (format "\n\n"))))
                ;; insert text of this recipe
                (insert-buffer-substring bigbuf begin end)
                ;; write out the file
                (write-region nil nil fnam nil nil nil nil))))))
      ;; put the big recipe list into alphabetical order
      (setq recipelist
            (sort recipelist (lambda (r1 r2)
                               (string-lessp (plist-get r1 :fnam)
                                             (plist-get r2 :fnam)))))
      ;; build up a list (sorted) of all tags found in all recipes
      (setq alltags (apply 'append
                           (mapcar
                            #'(lambda (r) (plist-get r :tags))
                            recipelist)))
      (setq alltags (sort (delete-dups alltags) 'string-lessp))
      (princ (format "alltags = %S\n" alltags))
      ;; for each tag (category), write out a file listing all
      ;; recipes having that tag
      (dolist (tag alltags)
        (princ (format "== tag: %s ==\n" tag))
        (with-temp-buffer
          (insert (format "#+pagetitle: recipe-category-%s\n\n" tag))
          (insert (format "** category: %s\n\n" tag))
          (insert "  [[[file:0-recipe-index.org][main recipe page]]]\n\n")
          (dolist (recipe recipelist)
            (when (member tag (plist-get recipe :tags))
              (insert (format "  - [[file:r-%s.org][%s]]"
                              (plist-get recipe :fnam)
                              (plist-get recipe :title)))
              (dolist (dum (plist-get recipe :tags))
                (insert (format " [[[file:c-%s.org][%s]]]" dum dum)))
              (insert "\n")
              (princ (format "   %s\n" (plist-get recipe :fnam)))))
          (insert "\n\n")
          (setq fnam (format "~/u/proj/recipe/org/c-%s.org" tag))
          (write-region nil nil fnam nil nil nil nil)
          (princ (format "wrote %s\n" fnam))))
      ;; write out an index file listing all recipes and all categories
      (with-temp-buffer
        ;; list of all categories at top
        (insert "#+pagetitle: recipe list\n\n")
        (insert "* categories\n\n")
        (dolist (tag alltags)
          (insert (format "  [[[file:c-%s.org][%s]]]\n" tag tag)))
        (insert "\n")
        ;; then list of all recipes
        (insert "* recipes\n\n")
        (dolist (recipe recipelist)
          (insert (format "  - [[file:r-%s.org][%s]]"
                          (plist-get recipe :fnam)
                          (plist-get recipe :title)))
          (dolist (dum (plist-get recipe :tags))
            (insert (format " [[[file:c-%s.org][%s]]]" dum dum)))
          (insert "\n")
          (princ (format "   %s\n" (plist-get recipe :fnam))))
        (insert "\n\n")
        (setq fnam "~/u/proj/recipe/org/0-recipe-index.org")
        (write-region nil nil fnam nil nil nil nil)
        (princ (format "wrote %s\n" fnam)))
      (length recipelist))))

(defun wja/do-element (e depth)
  "recursively dump an org syntax element"
  (let (typetag plist contents subelement i)
    (setq typetag (nth 0 e))
    (setq plist (nth 1 e))
    (setq contents (cddr e))
    (dotimes (i depth) (princ "  "))
    (princ (format "%d %s[%S,%S] titl='%s' clen=%d\n"
                   depth typetag
                   (plist-get plist ':begin)
                   (plist-get plist ':end)
                   (plist-get plist ':title)
                   (length contents)))
    (if contents
        (dolist (subelement contents)
          (wja/do-element subelement (+ 1 depth)))
      nil)))


(defun wja/firstn (n l)
  "return first n elements of list l"
  ;; (princ (format "n = %S, l=%S\n" n l))
  (let (len nchop)
    (setq len (length l))
    (setq nchop (- len n))
    ;; (princ (format "len=%d, nchop=%d\n" len nchop))
    (if (> nchop 0)
        (butlast l nchop)
      l)))
(defun wja/shorten (l)
  "return a copy of a structure in which every list is truncated to 4 elements"
  (if (listp l)
      (mapcar 'wja/shorten (wja/firstn 4 l))
    l))
