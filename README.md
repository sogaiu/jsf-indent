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

At the moment, there is only [integration with Emacs](doc/emacs.md).

The author hopes that it will be practical to support other editors
such as Neovim, Kakoune, Freja, and possibly VSCode.

Most of the "heavy lifting" is done via an external program written in
Janet, simplifying the editor side of things.  Note that because an
external program is involved, things are more likely to work if
this repository is cloned in full, as compared with just copying a
single file (e.g. just `jsf-indent.el`).

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
