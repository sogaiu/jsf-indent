;;; jsf-indent.el --- Janet spork-fmt-based indenting -*- lexical-binding: t; -*-

;;; Commentary:

;; Indentation via spork/fmt

;; Prerequisites

;; 1. Some janet major mode
;;
;; 2. Janet (needed to execute indentation code in external process)

;; Setup

;; 0. Clone the repository this file is in.  (Note: there should be
;;    a janet file in the same repository.  It is used for computing
;;    indentation, so the current elisp file is not sufficient on its
;;    own.)
;;
;; 1. Add directory containing this elisp file to `load-path'
;;
;; 2. Add following sort of thing to .emacs-equivalent:
;;
;;    (add-hook 'janet-mode-hook
;;              (lambda ()
;;                (require 'jsf-indent)
;;                (setq-local indent-line-function
;;                            #'jsf-indent-line)))

;;; Code:

(defvar jsf-indent--helper-path
  (expand-file-name
   (concat (expand-file-name
	    (file-name-directory (or load-file-name
				     buffer-file-name)))
	   "jsf-indent/jsf-indent.janet"))
  "Path to helper program to calculate indentation for a line.")

(defvar jsf-indent--debug-output
  nil
  "If non-nil, output debug info to *Messages* buffer.")

(defvar jsf-indent--temp-buffers
  '()
  "List of buffers to clean up before executing `jsf-indent--helper'.")

(defun jsf-indent-line ()
  "Indent current line as Janet code."
  (interactive)
  (when-let ((result (jsf-indent--calculate)))
    ;; remember the cursor position relative to the end of the buffer
    (let ((pos (- (point-max) (point)))
          (bol nil))
      ;; find the first non-whitespace character on the line
      (beginning-of-line)
      (setq bol (point))
      (skip-chars-forward " \t")
      ;; only adjust indentation if necessary
      (unless (= result (current-column))
        (delete-region bol (point))
        (indent-to result))
      ;; restore cursor sensibly
      (when (< (point) (- (point-max) pos))
        (goto-char (- (point-max) pos))))))

(defun jsf-indent--helper (start end)
  "Determine indentation of current line by asking Janet.

A region bounded by START and END is sent to a helper program."
  (interactive "r")
  (condition-case err
      (let ((temp-buffer (generate-new-buffer "*jsf-indent*"))
            (result nil))
        ;; clean up any old buffers
        ;; XXX: assumes all previous calls have completed before this call
        (dolist (old-buffer jsf-indent--temp-buffers)
          (kill-buffer old-buffer))
        (add-to-list 'jsf-indent--temp-buffers temp-buffer)
        (save-excursion
          (when jsf-indent--debug-output
            (message "region: %S"
                     (buffer-substring-no-properties start end)))
          (call-process-region start end
                               "janet"
                               ;; https://emacs.stackexchange.com/a/54353
                               nil `(,temp-buffer nil) nil
                               jsf-indent--helper-path)
          (set-buffer temp-buffer)
          (setq result
                (buffer-substring-no-properties (point-min) (point-max)))
          (when jsf-indent--debug-output
            (message "jsf-indent: %S" result))
          (cond ((string-match "^[0-9]+$" result)
                 (string-to-number result))
                ;; non-spork/fmt formatting detected
                ((string-match "^-1$" result)
                 nil)
                (t
                 (message "Unexpected indentation calculation result: <<%s>>"
                          result)))))
    (error
     (message "Error: %s %s" (car err) (cdr err)))))

(defun jsf-indent--calculate ()
  "Calculate indentation for the current line of Janet code."
  (save-excursion
    (let ((current (point))
          (bol nil)
          (cur-indent nil)
          (start nil)
          (end nil))
      (save-excursion
        (beginning-of-line)
        (setq bol (point))
        (skip-chars-forward " \t")
        (setq cur-indent (- (point) bol))
        (end-of-line)
        (setq end (point))
        (goto-char current)
        (jsf-indent--start-of-top-level)
        (setq start (point))
        (if-let ((new-indent (jsf-indent--helper start end)))
            new-indent
          cur-indent)))))

(defun jsf-indent--start-of-top-level-char-p (char)
  "Return non-nil if CHAR can start a top level container construct.

Supported top level container constructs include:

  * paren tuple            ()
  * square bracket tuple   []
  * struct                 {}
  * string                 \"\"
  * long string            ``
  * array                  @[] @()
  * table                  @{}
  * buffer                 @\"\"
  * long buffer            @````
  * quoted constructs      '() ~()

Note that constructs such as numbers, keywords, and symbols are excluded."
  (member char '(?\( ?\[ ?\{ ?\" ?\` ?\@ ?\~ ?\')))

(defun jsf-indent--start-of-top-level ()
  "If there is a top level container construct before point, move to its start.

Does not move point if there is no such construct.

If `open-paren-in-column-0-is-defun-start' is non-nil, assumes the first
character in each line can be relied upon to decide whether a top level
container construct begins there.

See `jsf-indent--start-of-top-level-char-p' for which characters determine
the start of a top level construct."
  (if (not open-paren-in-column-0-is-defun-start)
      (when (re-search-backward (rx bol (syntax open-parenthesis)) nil t)
        (goto-char (1- (match-end 0))))
    (when (not (bobp))             ; do nothing if at beginning of buffer
      (let ((pos (point)))
        ;; only consider positions before the starting point
        (if (bolp)
            (forward-line -1)
          (beginning-of-line))
        (if (jsf-indent--start-of-top-level-char-p (char-after (point)))
            (setq pos (point))
          (let ((done nil))
            (while (not done)
              (forward-line -1)
              (cond ((jsf-indent--start-of-top-level-char-p
                      (char-after (point)))
                     (setq pos (point))
                     (setq done t))
                    ((bobp)
                     (setq done t))))))
        (goto-char pos)))))

;; for lisp-indent-function
(defun jsf-indent-function (indent-point state)
  "When indenting a line within a function call, indent properly.

Ignores INDENT-POINT and STATE and just uses `jsf-indent--calculate'."
  (jsf-indent--calculate))

;; XXX: enumerate other indentation related functions and consider necessity
;;      e.g. indent-region-function

(provide 'jsf-indent)
;;; jsf-indent.el ends here
