;;; This is a script for compiling the Sassy assembler

;;; Note that you should *not* compile any files that contain syntax
;;; defintions that are intended for export, because those do not get
;;; propagated into the FASL file.

(load (string-append (current-larceny-root) "/Util/compile-tools.sch"))

(parameterize ((current-directory (string-append (current-larceny-root)
                                                 "/Lib/Sassy"))
               (current-require-path (cons "Lib/Sassy" 
                                           (current-require-path))))
  (let ((c (lambda (f . reqs) 
             (begin (display `(compiling ,f)) (newline))
             (compile-file/requiring f (append '(extras) reqs)))))
    (c "push-stacks.scm")
    (c "api.scm" 'srfi-9)
    (c "intern.scm")
    (c "macros.scm" 'srfi-9)
    (c "numbers.scm")
    (c "operands.scm")
    (c "text-block.scm" 'srfi-9)
    (parameterize ((global-optimization #f))
      ;; Pass3 is slow compiling this file...
      (c "opcodes.scm"))
    (c "text.scm")
    (c "parse.scm")
    (c "main.scm")
    (c "flat-bin.scm")
    (c "elf.scm")

    ))
