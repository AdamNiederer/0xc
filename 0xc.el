;;; 0xc.el --- Base conversion made easy

;; Copyright 2016 Adam Niederer

;; Author: Adam Niederer <adam.niederer@gmail.com>
;; URL: http://github.com/AdamNiederer/0xc
;; Version: 0.1
;; Keywords: base conversion
;; Package-Requires: ((emacs "24.4"))

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; 0xc-convert will convert any number with base inference, and
;; 0xc-convert-point replaces the number at the point with the
;; converted representation. Both accept prefix arguments for a
;; resulting base.
;; Exported names start with "0xc-"; private names start with
;; "0xc--".

;;; Code:

(require 'subr-x)
(require 'thingatpt)

(defgroup 0xc nil
  "Base conversion functions"
  :prefix "0xc-"
  :group 'languages
  :link '(url-link :tag "Github" "https://github.com/AdamNiederer/0xc")
  :link '(emacs-commentary-link :tag "Commentary" "0xc"))

(defcustom 0xc-strict nil
  "Whether or not 0xc will reject numbers with padding tokens in them (see 0xc-padding)"
  :tag "0xc Strict Parsing"
  :group '0xc
  :type 'boolean)

(defcustom 0xc-padding " _,."
  "Tokens which will automatically be stripped out of numbers when converting"
  :tag "0xc Padding Tokens"
  :group '0xc
  :type 'string)

(defcustom 0xc-clamp-ten t
  "Assume numbers with digits 2-9 in them are base ten. If both
0xc-clamp-ten and 0xc-clamp-hex are enabled, base ten will be favored."
  :tag "0xc Favor Base Ten"
  :group '0xc
  :type 'boolean)

(defcustom 0xc-clamp-hex t
  "Assume numbers with digits 2-f in them are base sixteen. If both
0xc-clamp-ten and 0xc-clamp-hex are enabled, base ten will be favored."
  :tag "0xc Favor 0xcadecimal"
  :group '0xc
  :type 'boolean)

(defcustom 0xc-max-base 16
  "Refuse to work with bases above this"
  :tag "0xc Maximum Base"
  :group '0xc
  :type 'integer)

(defcustom 0xc-default-base 10
  "The base to which 0xc-convert-point will convert to if no base is given"
  :tag "0xc Default Base"
  :group '0xc
  :type 'integer)

(defun 0xc-number-to-string (number base)
  "Convert a base-10 integer number into a different base string"
  (if (equal number 0) ""
    (concat
     (0xc-number-to-string (/ number base) base)
     (0xc--char-to-string (% number base) base))))

(defun 0xc--char-to-string (char &optional base)
  "Convert a base-10 character into a base-whatever character. If BASE is
provided, additional sanity checks will be performed before converting"
  (cond
   ((and base (> base 0xc-max-base)) (error "That base is larger than the maximum allowed base: %s" 0xc-max-base))
   ((and base (> char base)) (error "That character cannot fit in this base"))
   ((and base (> base 36)) (error "That base is too large to represent in ascii"))
   ((not (> 36 0xc-max-base char)) (error "That character is too large to represent in ascii")))
  (if (< char 10)
      (string (+ 48 char))
    (string (+ 55 char))))

(defun 0xc--string-to-number (number base)
  "Convert the reverse of a base-whatever number string into a base-10 integer"
  (if (string-empty-p number) 0
    (+ (* base (0xc--string-to-number (substring number 1) base)) (0xc--digit-value (substring number 0 1)))))

(defun 0xc-string-to-number (number &optional base)
  "Convert a base-whatever number string into base-10 integer"
  (when (not (string-match-p (format "^\\([0-9]*:?\\|0[bxodt]\\)[0-9A-z%s]+$" (if 0xc-strict 0xc-padding "")) number))
    (error "Not a number"))
  (let* ((number (0xc--strip-padding number))
         (base (or base (0xc--infer-base number))))
    (0xc--string-to-number (0xc--reverse-string (0xc--strip-base-hint number)) base)))

(defun 0xc--reverse-string (string)
  (if (string-empty-p string) ""
    (concat (0xc--reverse-string (substring string 1)) (substring string 0 1))))

(defun 0xc--strip-base-hint (number)
  "Return the number string without any base hints (0x, 0b, 3:, etc)"
  (cond ((string-match-p "^0[bxodt]" number)
         (substring number 2))
        ((string-match-p "^[0-9]*:" number)
         (or (nth 1 (split-string number ":" t "[ \t\n\r]")) ""))
        (t number)))

(defun 0xc--infer-base (number)
  "Return the base of a number, based on some heuristics"
  (when (not (string-match-p (format "^\\([0-9]+:\\|0[bxodt]\\)?[0-9A-z%s]+$" 0xc-padding) number))
    (error "Not a number"))
  (let ((prefix (substring number 0 2))
        (base (0xc--highest-base (0xc--strip-base-hint number))))
    (cond ((> base 0xc-max-base) (error "Number exceeds maximum allowed base: %s" 0xc-max-base))
          ((equal "0b" prefix) 2)
          ((equal "0t" prefix) 3)
          ((equal "0o" prefix) 8)
          ((equal "0d" prefix) 10)
          ((equal "0x" prefix) 16)
          ((string-match-p "^[0-9]+:" number)
           (string-to-number (car (split-string prefix ":" t "[ \t\n\r]"))))
          ((and 0xc-clamp-ten (>= 10 base 3)) 10)
          ((and 0xc-clamp-hex (>= 16 base 3)) 16)
          (t base))))

(defun 0xc--strip-padding (number)
  (string-join (split-string number (format "[%s]" 0xc-padding) t "[ \t\n\r]")))

(defun 0xc--highest-base (string)
  "Returns the base of the number according to heuristics"
  (if (string-empty-p string) 0
    (max (1+ (0xc--digit-value (substring string 0 1))) (0xc--highest-base (substring string 1)))))

(defun 0xc--digit-value (digit)
  "Returns the numeric value of a digit"
  (if (string-match-p "^[0-9]" digit)
      (string-to-number digit)
    (- (aref (upcase digit) 0) 55)))

;;;###autoload
(defun 0xc-convert (&optional number base silent)
  "Read a number and a base, and output its representation in said base.
If SILENT is non-nil, do not output anything"
  (interactive)
  (let* ((number (or number (read-from-minibuffer "Number: ")))
        (base (or base (read-minibuffer "Convert to base: ")))
        (converted (0xc-number-to-string (0xc-string-to-number number) base)))
    (when (not silent) (message converted))
    converted))

;;;###autoload
(defun 0xc-convert-point (&optional base)
  "Replace the number at point with its representation in base."
  (interactive "P")
  (let ((bounds (bounds-of-thing-at-point 'word))
        (number (word-at-point)))
    (replace-regexp number (0xc-number-to-string (0xc-string-to-number number) (or base 0xc-default-base)) nil (car bounds) (cdr bounds))))

(provide '0xc)
;;; 0xc.el ends here
