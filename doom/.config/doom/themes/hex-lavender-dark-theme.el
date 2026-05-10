;;; hex-lavender-dark-theme.el --- Description -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2026 Fábio Rodrigues
;;
;; Author: Fábio Rodrigues <fabio@fabio-torre>
;; Maintainer: Fábio Rodrigues <fabio@fabio-torre>
;; Created: May 08, 2026
;; Modified: May 08, 2026
;; Version: 0.0.1
;; Keywords: abbrev bib c calendar comm convenience data docs emulations extensions faces files frames games hardware help hypermedia i18n internal languages lisp local maint mail matching mouse multimedia news outlines processes terminals tex text tools unix vc wp
;; Homepage: https://github.com/fabiorodrigues0/hex-lavender-dark-theme
;; Package-Requires: ((emacs "24.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; hex-lavender-dark-theme.el ends here

;;; hex-lavender-dark-theme.el ends here

;;; hex-lavender-dark-theme.el --- Tema baseado na configuração Helix do portalsurfer. -*- no-byte-compile: t; -*-

;;; Commentary:
;; Tema escuro inspirado no tema hex_lavender_dark do Helix editor.

;;; Code:
(deftheme hex-lavender-dark "Um tema baseado na configuração Helix do portalsurfer.")

(let* ((bg         "#0d0d0b")
       (bg-alt     "#0a0a08")
       (base1      "#1c1f1b")
       (base2      "#2b3444")
       (base3      "#404768")
       (base6      "#878480")
       (base8      "#9db2b8")
       (fg         "#8a8094")
       (magenta    "#8e80de")
       (violet     "#ff2e5f")
       (cyan       "#a0c7cf")
       (operators  "#7b89a3")
       (yellow     "#29bbff")
       (selection  "#2a1a2e")
       (hl-line    "#1a1520"))

  (custom-theme-set-faces
   'hex-lavender-dark
   ;; Base
   `(default                      ((t (:background ,bg :foreground ,fg))))
   `(fringe                       ((t (:background ,bg))))
   `(hl-line                      ((t (:background ,hl-line))))
   `(line-number                  ((t (:foreground ,base3 :background ,bg))))
   `(line-number-current-line     ((t (:foreground ,yellow :background ,bg))))
   ;; Syntax
   `(font-lock-comment-face       ((t (:foreground ,base3 :slant italic))))
   `(font-lock-keyword-face       ((t (:foreground ,magenta :weight bold))))
   `(font-lock-type-face          ((t (:foreground ,operators :weight bold))))
   `(font-lock-string-face        ((t (:foreground ,base6))))
   `(font-lock-builtin-face       ((t (:foreground ,magenta))))
   `(font-lock-constant-face      ((t (:foreground ,cyan))))
   `(font-lock-function-name-face ((t (:foreground ,base8))))
   `(font-lock-variable-name-face ((t (:foreground ,fg))))
   ;; UI
   `(region                       ((t (:background ,selection))))
   `(highlight                    ((t (:background ,hl-line))))
   `(vertical-border              ((t (:foreground ,base1))))
   ;; Modeline
   `(mode-line                    ((t (:background ,base1 :foreground ,fg))))
   `(mode-line-inactive           ((t (:background ,bg-alt :foreground ,base3))))
   `(header-line                  ((t (:background ,bg :foreground ,fg))))
   `(doom-modeline-bar            ((t (:background ,violet))))
   `(doom-modeline-buffer-file    ((t (:foreground ,base8))))
   `(doom-modeline-buffer-path    ((t (:foreground ,base6))))
   `(doom-modeline-project-dir    ((t (:foreground ,magenta))))))

(provide-theme 'hex-lavender-dark)
;;; hex-lavender-dark-theme.el ends here
