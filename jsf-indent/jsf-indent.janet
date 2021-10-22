### including spork's fmt.janet to make a single file, for those portions:

# Copyright (c) 2020 Calvin Rose and contributors

# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

###
### fmt.janet
###
### Janet code formatter.
###

(defn- pnode
  "Make a capture function for a node."
  [tag]
  (fn [x] [tag x]))

(def- parse-peg
  "Peg to parse Janet with extra information, namely comments."
  (peg/compile
    ~{:ws (+ (set " \t\r\f\0\v") '"\n")
      :readermac (set "';~,|")
      :symchars (+ (range "09" "AZ" "az" "\x80\xFF") (set "!$%&*+-./:<?=>@^_"))
      :token (some :symchars)
      :hex (range "09" "af" "AF")
      :escape (* "\\" (+ (set "ntrzfev0\"\\")
                         (* "x" :hex :hex)
                         (* "u" :hex :hex :hex :hex)
                         (* "U" :hex :hex :hex :hex :hex :hex)
                         (error (constant "bad hex escape"))))
      :comment (/ (* "#" '(any (if-not (+ "\n" -1) 1)) (+ "\n" -1)) ,(pnode :comment))
      :span (/ ':token ,(pnode :span))
      :bytes '(* "\"" (any (+ :escape (if-not "\"" 1))) "\"")
      :string (/ :bytes ,(pnode :string))
      :buffer (/ (* "@" :bytes) ,(pnode :buffer))
      :long-bytes '{:delim (some "`")
                    :open (capture :delim :n)
                    :close (cmt (* (not (> -1 "`")) (-> :n) ':delim) ,=)
                    :main (drop (* :open (any (if-not :close 1)) :close))}
      :long-string (/ :long-bytes ,(pnode :string))
      :long-buffer (/ (* "@" :long-bytes) ,(pnode :buffer))
      :ptuple (/ (group (* "(" (any :input) (+ ")" (error)))) ,(pnode :ptuple))
      :btuple (/ (group (* "[" (any :input) (+ "]" (error)))) ,(pnode :btuple))
      :struct (/ (group (* "{" (any :input) (+ "}" (error)))) ,(pnode :struct))
      :parray (/ (group (* "@(" (any :input) (+ ")" (error)))) ,(pnode :array))
      :barray (/ (group (* "@[" (any :input) (+ "]" (error)))) ,(pnode :array))
      :table (/ (group (* "@{" (any :input) (+ "}" (error)))) ,(pnode :table))
      :rmform (/ (group (* ':readermac
                           (group (any :non-form))
                           :form))
                 ,(pnode :rmform))
      :form (choice :rmform
                    :parray :barray :ptuple :btuple :table :struct
                    :buffer :string :long-buffer :long-string
                    :span)
      :non-form (choice :ws :comment)
      :input (choice :non-form :form)
      :main (* (any :input) (+ -1 (error)))}))

(defn- make-tree
  "Turn a string of source code into a tree that will be printed"
  [source]
  [:top (peg/match parse-peg source)])

(defn- remove-extra-newlines
  "Remove leading and trailing newlines. Also remove
   some extra consecutive newlines."
  [node]
  (match node
    [tag (xs (array? xs))]
    (do
      (while (= "\n" (array/peek xs)) (array/pop xs)) # remove trailing newlines
      (when-let [index (find-index |(not= "\n" $) xs)]
        (array/remove xs 0 index)) # remove leading newlines
      # remove too many consecutive newlines
      (def max-consec (if (= tag :top) 3 2))
      (var i 0)
      (var consec-count 0)
      (while (< i (length xs))
        (if (= (in xs i) "\n")
          (if (= consec-count max-consec) (array/remove xs i) (do (++ i) (++ consec-count)))
          (do (set consec-count 0) (++ i))))
      node)
    node))

(def- indent-2-forms
  "A list of forms that are control forms and should be indented two spaces."
  (invert ["fn" "match" "with" "with-dyns" "def" "def-" "var" "var-" "defn" "defn-"
           "varfn" "defmacro" "defmacro-" "defer" "edefer" "loop" "seq" "generate" "coro"
           "for" "each" "eachp" "eachk" "case" "cond" "do" "defglobal" "varglobal"
           "if" "when" "when-let" "when-with" "while" "with-syms" "with-vars"
           "if-let" "if-not" "if-with" "let" "short-fn" "try" "unless" "default" "forever"
           "repeat" "eachy" "forv" "compwhen" "compif" "ev/spawn" "ev/do-thread" "ev/with-deadline"
           "label" "prompt"]))

(def- indent-2-peg
  "Peg to use to fuzzy match certain forms."
  (peg/compile ~(+ "with-" "def" "if-" "when-")))

(defn- check-indent-2
  "Check if a tuple needs a 2 space indent or not"
  [items]
  (if-let [[tag body] (get items 0)]
    (cond
      (= "\n" (get items 1)) true
      (not= tag :span) nil
      (in indent-2-forms body) true
      (peg/match indent-2-peg body) true)))

(defn- fmt
  "Emit formatted."
  [tree]

  (var col 0)
  (def ident-stack @[])
  (var ident "")
  (def white @"")

  (defn emit [& xs] (each x xs (+= col (length x)) (prin x)))
  (defn indent [&opt delta]
    (array/push ident-stack ident)
    (set ident (string/repeat " " (+ col (or delta 0)))))
  (defn dedent [] (set ident (array/pop ident-stack)))
  (defn flushwhite [] (emit white) (buffer/clear white))
  (defn dropwhite [] (buffer/clear white))
  (defn addwhite [] (buffer/push-string white " "))
  (defn newline [] (dropwhite) (print) (buffer/push-string white ident) (set col 0))

  # Mutual recursion
  (var fmt-1-recur nil)

  (defn emit-body
    [open xs close &opt delta]
    (emit open)
    (indent delta)
    (each x xs (fmt-1-recur x))
    (dropwhite)
    (dedent)
    (emit close)
    (addwhite))

  (defn emit-funcall
    [xs]
    (emit "(")
    (def len (length xs))
    (when (pos? len)
      (fmt-1-recur (xs 0))
      (indent 1)
      (for i 1 len (fmt-1-recur (xs i)))
      (dropwhite)
      (dedent))
    (emit ")")
    (addwhite))

  (defn emit-string
    [x]
    (def parts (interpose "\n" (string/split "\n" x)))
    (each p parts (if (= p "\n") (do (newline) (dropwhite)) (emit p))))

  (defn emit-rmform
    [rm nfs form]
    (emit rm)
    (each nf nfs
      (fmt-1-recur nf))
    (fmt-1-recur form))

  (defn fmt-1
    [node]
    (remove-extra-newlines node)
    (unless (= node "\n") (flushwhite))
    (match node
      "\n" (newline)
      [:comment x] (do (emit "#" x) (newline))
      [:span x] (do (emit x) (addwhite))
      [:string x] (do (emit-string x) (addwhite))
      [:buffer x] (do (emit "@") (emit-string x) (addwhite))
      [:array xs] (emit-body "@[" xs "]")
      [:btuple xs] (emit-body "[" xs "]")
      [:ptuple xs] (if (check-indent-2 xs)
                     (emit-body "(" xs ")" 1)
                     (emit-funcall xs))
      [:struct xs] (emit-body "{" xs "}")
      [:table xs] (emit-body "@{" xs "}")
      [:rmform [rm nfs form]] (emit-rmform rm nfs form)
      [:top xs] (emit-body "" xs "")))

  (set fmt-1-recur fmt-1)
  (fmt-1 tree)
  (newline)
  (flush))

#
# Public API
#

(defn format-print
  "Format a string of source code and print the result."
  [source]
  (-> source make-tree fmt))

(defn format
  "Format a string of source code to a buffer."
  [source]
  (def out @"")
  (with-dyns [:out out]
    (format-print source))
  out)

(defn format-file
  "Format a file"
  [file]
  (def source (slurp file))
  (def out (format source))
  (spit file out))

# end of spork/fmt.janet

(comment

  # example parser/state based on `{:a 1`
  @{:delimiters "{"
    :frames @[@{:args @[]
                :column 0
                :line 1
                :type :root}
              @{:args @[:a 1]
                :column 1
                :line 1
                :type :struct}]}

  )

(defn missing-delims
  [fragment]
  (var missing @"")
  (def p (parser/new))
  (parser/consume p fragment)
  # XXX: in another code base, had a problem w/ parser/eof, but...
  #      parser/eof is necessary for some backtick cases, e.g. not possible
  #      to tell if ``hello`` is complete, as it could be the beginning of
  #      ``hello```!``
  (parser/eof p)
  (when-let [state (parser/state p)
             delims (state :delimiters)]
    (when (pos? (length delims))
      (each d (reverse delims)
        (case d
          (chr "(") (buffer/push-string missing ")")
          (chr "[") (buffer/push-string missing "]")
          (chr "{") (buffer/push-string missing "}")
          (chr `"`) (buffer/push-string missing `"`)
          (chr "`") (buffer/push-string missing "`")
          # XXX: should not happen
          (errorf "Unrecognized delimiter character: %s"
                  (string (buffer/push-byte @"" d)))))))
  missing)

(comment

  (missing-delims "(defn a")
  # => @")"

  (missing-delims "{:a 1")
  # => @"}"

  (missing-delims "[:x :y")
  # => @"]"

  (missing-delims
    (string "{:a 1\n"
            " :b"))
  # => @"}"

  (missing-delims
    (string "(defn my-fn\n"
            "  [x]\n"
            "  (+ x 1"))
  # => @"))"

  (missing-delims `"nice string"`)
  # => @""

  (missing-delims `"not quite a string`)
  # => @`"`

  (missing-delims `("what is going on?)`)
  # => @`")`

  (missing-delims "``hello``")
  # => @""

  (missing-delims "``hello```")
  # => @"`"

  (missing-delims "1")
  # => @""

  (missing-delims "")
  # => @""

  (missing-delims
    (string "``\n"
            "  hello"))
  # => @"``"

  )

(defn indentation-pos
  [line]
  (if-let [[pos]
           (peg/match ~(sequence (any :s)
                                 (if-not " " 1)
                                 (capture (position)))
                       line)]
    (dec pos)
    # when line only has whitespace or is empty, return 0
    0))

(comment

  (indentation-pos "    3")
  # => 4

  (indentation-pos ":a")
  # => 0

  (indentation-pos " ")
  # => 0

  (indentation-pos "")
  # => 0

  )

# XXX: consider ignoring non-space whitespace differences
(defn lines-differ?
  [old-lines new-lines]
  (not (deep= old-lines new-lines)))

(comment

  (lines-differ?
    @["line one"
      "line two"]
    @["line one"
      "line twoo"])
  # => true

  (lines-differ?
    @["line one"
      "line two"]
    @["line one"
      "line two"])
  # => false

  )

# XXX: non-space whitespace (e.g. \t, \0, \f, \v, etc.) might cause issues
(defn calc-last-line-indent
  [fragment]
  (def input-lines
    (string/split "\n" fragment))
  # replace the last line because:
  # 1) indentation of a line only depends on previous lines when
  #    not in a multiline string
  # 2) prevent spork from "lifting" closing delimiters to previous line
  (def lead-ws-pos (indentation-pos (array/pop input-lines)))
  (array/push input-lines
              # maintain leading whitespace
              (string (string/repeat " " lead-ws-pos)
                      "__MY_FUN_SENTINEL__"))
  (def new-fragment
    (string/join input-lines "\n"))
  # determine any missing delimiters for the new fragment
  (def closing-delims (missing-delims new-fragment))
  # format
  (def formatted
    (format (string new-fragment closing-delims)))
  (def lines
    (string/split "\n" formatted))
  # remove an extra blank line that spork/fmt seems to add
  (when (empty? (array/peek lines))
    # XXX: though, is this always correct?
    (array/pop lines))
  (def target-line (array/pop lines))
  # diff to see if original indentation was not spork/fmt compliant
  (def old-last-line (array/pop input-lines))
  (if (not (lines-differ? input-lines lines))
    (indentation-pos target-line)
    # not spork/fmt-compliant: indicate via -1
    -1))

(comment

  (calc-last-line-indent
    # non-spork/fmt formatting
    (string " (defn a\n"
            "   1"))
  # => -1

  (calc-last-line-indent "(+ 2 8)")
  # => 0

  (calc-last-line-indent ":a")
  # => 0

  (calc-last-line-indent
    (string "(+ 2\n"
            "8)"))
  # => 3

  (calc-last-line-indent
    (string "(defn my-fn\n"
            "  [x]\n"
            "(+ x"))
  # => 2

  (calc-last-line-indent
    (string "{:a 1\n"
            ":b"))
  # => 1

  (calc-last-line-indent
    (string "`\n"
            " hello"))
  # => 1

  (calc-last-line-indent
    (string "``\n"
            "  hello"))
  # => 2

  (calc-last-line-indent
    (string "{:a\n"
            `""`))
  # => 1

  (calc-last-line-indent
    (string "{:a\n"
            "[]"))
  # => 1

  (calc-last-line-indent
    (string "(def a\n"
            "(print 1))"))
  # => 2

  (calc-last-line-indent "(def a")
  # => 0

  )

# XXX: tabs (and other non-space whitespace) are not handled -- problem?
(defn main
  [& args]
  (def indent
    (calc-last-line-indent (file/read stdin :all)))
  (eprint "indent: " indent)
  (print indent))
