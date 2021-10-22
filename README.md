# jsf-indent

Indentation Based on Janet's spork/fmt

## Background

It's not unusual for the terms "indentation" and "formatting" to be
used somewhat interchangeably.  However, below they will be treated as
separate but related ideas.

Formatting tends to be applied to a file or per top-level form.
Indentation tends to be a per-line operation.

When indentation occurs, the changes are local and few.  Compared to
formatting an entire file or buffer, "taking in" the changes is spread
out over time.  Formatting an entire file or buffer tends to present a
situation where either one does not review all of the changes or one
is faced with the task of going through changes across the target
range all at once.

## Why

* Usually want to indent consistently with spork/fmt
* [Sometimes want to deviate from spork/fmt](https://github.com/janet-lang/jpm/blob/6b2173e3606dc649f8ac63cf950d2a1b49fe573d/jpm/shutil.janet#L34-L37)
* Do not want to batch review "formatting" changes to code
* Do not want "formatting" changes to occur "behind one's back"

## Editor Support

At the moment, there is only integration with Emacs.  Most of the
"heavy lifting" is done via an external program written in Janet,
simplifying the editor side of things.

The author hopes that it will be practical to support other editors
such as Neovim, Kakoune, Freja, and possibly VSCode.

### Emacs

0. Ensure a janet-mode is installed and configured.

1. Clone this repository.

2. Add the repository directory to `load-path`.

3. Add the following to a `.emacs`-equivalent:
    ```
    (add-hook 'janet-mode-hook
              (lambda ()
                (require 'jsf-indent)
                (setq-local indent-line-function
                            #'jsf-indent-line)))
    ```

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
* llmII - discussion
* pyrmont - discussion
* saikyun - discussion
