;; couple o' simple checks from
;; https://masteringemacs.com/article/speed-up-emacs-libjansson-native-elisp-compilation
(defun wob/check-perf ()
  (interactive)
  (display-buffer "*Messages*")
  (if (and (fboundp 'native-comp-available-p)
           (native-comp-available-p))
      (message "Native compilation is available")
    (message "Native complation is *not* available"))

  (if (functionp 'json-serialize)
      (message "Native JSON is available")
    (message "Native JSON is *not* available"))

  (message "Running spawn benchmark...")
  (benchmark 100 '(call-process "/usr/bin/true" nil nil nil)))

;; this will get substituted at install time to the install directory
(setq w08r-site-dir nil)

;; set the c source dir based on site install location
(setq find-function-C-source-directory (concat w08r-site-dir "/src"))

;; pdf-tools binaries
(setq pdf-info-epdfinfo-program (concat w08r-site-dir "/bin/epdfinfo"))

;; library path for gccjit
(setq native-comp-driver-options nil)
