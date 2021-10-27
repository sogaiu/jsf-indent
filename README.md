# jsf-indent

Indentation Based on Janet's spork/fmt

## Background

It's not unusual for the terms
["indentation" and "formatting"](doc/indentation-and-formatting.md)
to be used somewhat interchangeably.  However, below they will be treated
as separate but related ideas.

## Why

* Usually want to indent consistently with spork/fmt
* Sometimes want to [deviate from spork/fmt](https://github.com/janet-lang/jpm/blob/6b2173e3606dc649f8ac63cf950d2a1b49fe573d/jpm/shutil.janet#L34-L37)
* Do not want to batch review "formatting" changes to code
* Do not want "formatting" changes to occur "behind one's back"

## Editor Support

At the moment, there is only integration with Emacs.  Most of the
"heavy lifting" is done via an external program written in Janet,
simplifying the editor side of things.

The author hopes that it will be practical to support other editors
such as Neovim, Kakoune, Freja, and possibly VSCode.

### Emacs

How to set things up varies a bit depending on how one manages one's
Emacs, e.g. straight.el, Doom, etc.  What's common to all situations
is likely:

* Ensure a janet-mode is installed and configured.

* Clone this repository.

#### straight.el

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

#### Doom

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

#### Vanilla

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

#### package.el

* Sorry, no support for that.  The Vanilla instructions should work
  though.

## Features

* Indentation can be consistent with spork/fmt
* Usually delimiters do not have to be closed for indentation to succeed
* Can opt-out of spork/fmt compliance within forms
* Core piece is an external program written in Janet
* Relies as little as possible on special editor features

## License

Since spork/fmt is included, [spork's license](https://github.com/janet-lang/spork/blob/master/LICENSE) applies to at least that portion.

## Credits

* bakpakin - spork/fmt is included to avoid update-related changes
* llmII - discussion and testing
* pyrmont - discussion
* saikyun - discussion
