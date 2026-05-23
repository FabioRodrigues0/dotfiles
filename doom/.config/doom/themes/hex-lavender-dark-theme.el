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

(let* ((bg         "#131410")
       (bg-alt     "#0e0e0d")
       (ruler      "#1c1f1b")
       (base3      "#404768")
       (base4      "#61586f")
       (base6      "#878480")
       (base7      "#8e80de")
       (base8      "#7b89a3")
       (base10     "#9db2b8")
       (base11     "#a0c7cf")
       (fg         base4)
       (highlight  "#ff2e5f")
       (cyan       base11)
       (yellow     "#29bbff")
       (green      "#0affa9")
       (selection  "#290019")
       (selection-fg "#958e9a"))

  (custom-theme-set-faces
   'hex-lavender-dark
   ;; Base
   `(default                      ((t (:background ,bg :foreground ,fg))))
   `(cursor                       ((t (:background ,yellow))))
   `(fringe                       ((t (:background ,bg :foreground ,base3))))
   `(hl-line                      ((t (:background ,ruler))))
   `(line-number                  ((t (:foreground ,base3 :background ,bg))))
   `(line-number-current-line     ((t (:foreground ,yellow :background ,bg))))
   `(minibuffer-prompt            ((t (:foreground ,base7 :weight bold))))
   `(shadow                       ((t (:foreground ,base3))))
   ;; Syntax
   `(font-lock-comment-face       ((t (:foreground ,base3 :slant italic))))
   `(font-lock-keyword-face       ((t (:foreground ,base6))))
   `(font-lock-type-face          ((t (:foreground ,base8 :weight bold))))
   `(font-lock-string-face        ((t (:foreground ,base6 :slant italic))))
   `(font-lock-builtin-face       ((t (:foreground ,base7))))
   `(font-lock-constant-face      ((t (:foreground ,cyan))))
   `(font-lock-function-name-face ((t (:foreground ,base10))))
   `(font-lock-variable-name-face ((t (:foreground ,fg))))
   `(font-lock-doc-face           ((t (:foreground ,green :slant italic))))
   `(font-lock-preprocessor-face  ((t (:foreground ,base7))))
   `(font-lock-warning-face       ((t (:foreground ,highlight :weight bold))))
   ;; UI
   `(region                       ((t (:background ,selection :foreground ,selection-fg))))
   `(highlight                    ((t (:background ,ruler))))
   `(lazy-highlight               ((t (:background ,selection :foreground ,selection-fg))))
   `(isearch                      ((t (:background ,highlight :foreground ,bg-alt :weight bold))))
   `(show-paren-match             ((t (:background ,bg-alt :foreground ,highlight :weight bold))))
   `(show-paren-mismatch          ((t (:background ,highlight :foreground ,bg-alt :weight bold))))
   `(vertical-border              ((t (:foreground ,ruler))))
   `(window-divider               ((t (:foreground ,ruler))))
   `(window-divider-first-pixel   ((t (:foreground ,ruler))))
   `(window-divider-last-pixel    ((t (:foreground ,ruler))))
   `(tooltip                      ((t (:background ,bg-alt :foreground ,fg))))
   `(link                         ((t (:foreground ,cyan :underline t))))
   `(error                        ((t (:foreground ,highlight :weight bold))))
   `(warning                      ((t (:foreground "#ffbf00" :weight bold))))
   `(success                      ((t (:foreground ,green :weight bold))))
   ;; Modeline
   `(mode-line                    ((t (:background ,bg-alt :foreground ,fg))))
   `(mode-line-inactive           ((t (:background ,bg-alt :foreground ,base3))))
   `(header-line                  ((t (:background ,bg :foreground ,fg))))
   `(tab-line                     ((t (:background ,bg-alt :foreground ,fg))))
   `(tab-line-tab                 ((t (:background ,bg :foreground ,base7))))
   `(tab-line-tab-inactive        ((t (:background ,bg-alt :foreground ,base3))))
   `(doom-modeline-bar            ((t (:background ,highlight))))
   `(doom-modeline-buffer-file    ((t (:foreground ,base10))))
   `(doom-modeline-buffer-path    ((t (:foreground ,base6))))
   `(doom-modeline-project-dir    ((t (:foreground ,base7))))))

(provide-theme 'hex-lavender-dark)
;;; hex-lavender-dark-theme.el ends here
