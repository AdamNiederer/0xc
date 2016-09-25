;;; hex.el --- Easy changes of base in emacs

;; Copyright 2016 Adam Niederer

;; Author: Adam Niederer <adam.niederer@gmail.com>
;; URL: http://github.com/AdamNiederer/hex
;; Version: 0.1
;; Keywords: base conversion
;; Package-Requires: ()

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

;; hex-convert will convert any number with base inference, and
;; hex-convert-point replaces the number at the point with the
;; converted representation. Both accept prefix arguments for a
;; resulting base.
;; Exported names start with "hex-"; private names start with
;; "hex--".

;;; Code:

(defgroup hex nil
  "Base conversion functions"
  :prefix "hex-"
  :group 'languages
  :link '(url-link :tag "Github" "https://github.com/AdamNiederer/hex")
  :link '(emacs-commentary-link :tag "Commentary" "hex"))

(defcustom hex-strict nil
  "Whether or not hex will reject numbers with padding tokens in them (see hex-padding)"
  :tag "Hex Strict Parsing"
  :group 'hex
  :type 'boolean)

(defcustom hex-padding " _,."
  "Tokens which will automatically be stripped out of numbers when converting"
  :tag "Hex Padding Tokens"
  :group 'hex
  :type 'string)

(defcustom hex-clamp-ten t
  "Assume numbers with digits 2-9 in them are base ten. If both
hex-clamp-ten and hex-clamp-hex are enabled, base ten will be favored."
  :tag "Hex Favor Base Ten"
  :group 'hex
  :type 'boolean)

(defcustom hex-clamp-hex t
  "Assume numbers with digits 2-f in them are base sixteen. If both
hex-clamp-ten and hex-clamp-hex are enabled, base ten will be favored."
  :tag "Hex Favor Hexadecimal"
  :group 'hex
  :type 'boolean)

(defcustom hex-max-base 16
  "Refuse to work with bases above this"
  :tag "Hex Maximum Base"
  :group 'hex
  :type 'integer)

(defcustom hex-default-base 10
  "The base to which hex-convert-point will convert to if no base is given"
  :tag "Hex Default Base"
  :group 'hex
  :type 'integer)

(defun hex-number-to-string (number base)
  "Convert a base-10 integer number into a different base string"
  (if (equal number 0) ""
    (concat
     (hex-number-to-string (/ number base) base)
     (hex--char-to-string (% number base) base))))

(defun hex--char-to-string (char &optional base)
  "Convert a base-10 character into a base-whatever character. If BASE is
provided, additional sanity checks will be performed before converting"
  (cond
   ((and base (> base hex-max-base)) (error "That base is larger than the maximum allowed base: %s" hex-max-base))
   ((and base (> char base)) (error "That character cannot fit in this base"))
   ((and base (> base 36)) (error "That base is too large to represent in ascii"))
   ((not (> 36 hex-max-base char)) (error "That character is too large to represent in ascii")))
  (if (< char 10)
      (string (+ 48 char))
    (string (+ 55 char))))

(defun hex--string-to-number (number base)
  "Convert the reverse of a base-whatever number string into a base-10 integer"
  (if (string-empty-p number) 0
    (+ (* base (hex--string-to-number (substring number 1) base)) (hex--digit-value (substring number 0 1)))))

(defun hex-string-to-number (number &optional base)
  "Convert a base-whatever number string into base-10 integer"
  (when (not (string-match-p (format "^\\([0-9]*:?\\|0[bxodt]\\)[0-9A-z%s]+$" (if hex-strict hex-padding "")) number))
    (error "Not a number"))
  (let ((number (hex--strip-padding (hex--strip-base-hint number))))
    (let ((base (or base (hex--infer-base number))))
      (hex--string-to-number (hex--reverse-string number) base))))

(defun hex--reverse-string (string)
  (if (string-empty-p string) ""
    (concat (hex--reverse-string (substring string 1)) (substring string 0 1))))

(defun hex--strip-base-hint (number)
  "Return the number string without any base hints (0x, 0b, 3:, etc)"
  (cond ((string-match-p "^0[bxodt]" number)
	 (substring number 2))
	((string-match-p "^[0-9]:" number)
	 (nth 3 (split-string prefix ":" t "[ \t\n\r]")))
	(t number)))

(defun hex--infer-base (number)
  "Return the base of a number, based on some heuristics"
  (when (not (string-match-p (format "^\\([0-9]+:\\|0[bxodt]\\)?[0-9A-z%s]+$" hex-padding) number))
    (error "Not a number"))
  (let ((prefix (substring number 0 2))
	(base (hex--highest-base number)))
    (when (> base hex-max-base)
      (error "Number exceeds maximum allowed base: %s" hex-max-base))
    (cond ((equal "0b" prefix) 2)
	  ((equal "0t" prefix) 3)
	  ((equal "0o" prefix) 8)
	  ((equal "0d" prefix) 10)
	  ((equal "0x" prefix) 16)
	  ((string-match-p "^[0-9]:" number)
	   (string-to-number (first (split-string prefix ":" t "[ \t\n\r]"))))
	  ((and hex-clamp-ten (>= 10 base 3)) 10)
	  ((and hex-clamp-hex (>= 16 base 3)) 16)
	  (t base))))

(defun hex--strip-padding (number)
  (string-join (split-string number (format "[%s]" hex-padding) t "[ \t\n\r]")))

(defun hex--highest-base (string)
  "Returns the base of the number according to heuristics"
  (if (string-empty-p string) 0
    (max (1+ (hex--digit-value (substring string 0 1))) (hex--highest-base (substring string 1)))))

(defun hex--digit-value (digit)
  "Returns the numeric value of a digit"
  (if (string-match-p "^[0-9]" digit)
      (string-to-number digit)
    (- (aref (upcase digit) 0) 55)))

;;;###autoload
(defun hex-convert (&optional number base)
  "Read a number and a base, and output its representation in said base"
  (interactive "P")
  (let ((number (or number (read-from-minibuffer "Number: ")))
	(base (or base (read-minibuffer "Convert to base: "))))
    (message (hex-number-to-string (hex-string-to-number number) base))))

;;;###autoload
(defun hex-convert-point (&optional base)
  "Replace the number at point with its representation in base."
  (interactive "P")
  (let ((bounds (bounds-of-thing-at-point 'word))
	(number (word-at-point)))
    (replace-regexp number (hex-number-to-string (hex-string-to-number number) (or base hex-default-base)) nil (car bounds) (cdr bounds))))

(provide 'hex)
;;; hex.el ends here
