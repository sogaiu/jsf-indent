# Emacs

## Setup

How to set things up varies a bit depending on how one manages one's
Emacs, e.g. straight.el, Doom, etc.  What's common to all situations
is likely:

* Ensure a janet-mode is installed and configured.

* Clone this repository.

### straight.el

* I add the following sort of thing to my `.emacs`-equivalent:
    ```
    (straight-use-package
      '(jsf-indent :host github
                   :repo "sogaiu/jsf-indent"
                   :files ("*.el" "jsf-indent")))

    (use-package jsf-indent
      :straight t
      :config
      (add-hook 'janet-mode-hook
                (lambda ()
                  (setq-local indent-line-function
                              #'jsf-indent-line))))
    ```

### Doom

* Allegedly, the following is valid for Doom:
    ```
    (package! jsf-indent
      :recipe (:type git
               :host github
               :repo "sogaiu/jsf-indent"
               :files (:defaults ("jsf-indent/" "jsf-indent/*"))))

    (use-package! jsf-indent
      :config
      (add-hook 'janet-mode-hook
                (lambda ()
                  (setq-local indent-line-function
                              #'jsf-indent-line))))
    ```

### Vanilla

* If you cloned to `~/src/jsf-indent`, add the following to your
  `.emacs`-equivalent:
    ```
    (add-to-list 'load-path
                 (expand-file-name "~/src/jsf-indent"))

    (add-hook 'janet-mode-hook
              (lambda ()
                (require 'jsf-indent)
                (setq-local indent-line-function
                            #'jsf-indent-line)))
    ```

### package.el

* Sorry, no support for that.  The Vanilla instructions should work
  though.

## Caveats

If your source code is compliant with the [Left Margin Convention](https://www.gnu.org/software/emacs/manual/html_node/emacs/Left-Margin-Paren.html)
it may be that indentation operations may be more efficient.

To follow that convention in Janet's case, the characters to avoid having
in column zero (unless they are being used to indicate the start of a
top-level form) include:

* ( - Open parenthesis
* [ - Open square bracket
* { - Open curly brace
* " - Double quote
* ` - Backtick
* @ - At mark
* ~ - Tilde
* ' - Single quote

Docstrings and long strings are some of the place these might be likely to
crop up.

If you do not wish to follow this convention, doing the following in Emacs
may help (at the potential cost of slower processing and possibly not
working as well in certain situations):

```
(setq open-paren-in-column-0-is-defun-start nil)
```

So far, the author's opinion is that following the convention is a
worthwhile trade-off.  What one gains in return is likelihood of tooling
working more reliably and in more contexts.  One reason for this is that
it becomes possible to rely on it as an indication of a programmer's intent
of where a top-level construct begins.  This can be an issue for
efficiency, correct operation, and robustness in the face of code that is
not-quite-right (e.g. missing delimiters).

If you don't have a particular preference, please consider following it.
