;;; Copyright 2015 William D Clinger
;;;
;;; $Id$

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Implements cond-expand for R7RS define-library.
;;;
;;; The code in this file assumes lib/R6RS/r6rsmode.sch has
;;; been loaded.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Given a cond-expand form in which the <feature requirement>
;;; part of each clause is a raw s-expression but the
;;; expressions or declarations are in a form that should not
;;; be examined by this code, returns a list of the selected
;;; expressions or declarations.
;;;
;;; If no <feature requirements> evaluates to true, returns an
;;; empty list.

(define (larceny:cond-expand form)
  (larceny:interpret-cond-expand (cdr form)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Private to this file.
;;;
;;; From R7RS section 4.2.1:
;;;
;;; A <feature requirement> takes one of the following forms:
;;;
;;;     <feature identifier>
;;;     (library <library name>)
;;;     (and <feature requirement> ...)
;;;     (or <feature requirement> ...)
;;;     (not <feature requirement>)
;;;
;;; R7RS Appendix B lists these standard feature identifiers:
;;;
;;;     r7rs
;;;     exact-closed
;;;     exact-complex
;;;     ieee-float
;;;     full-unicode
;;;     ratios
;;;     posix
;;;     windows
;;;     unix, darwin, gnu-linux, bsd, freebsd, solaris, ...
;;;     i386, x86-64, ppc, sparc, jvm, clr, llvm, ...
;;;     ilp32, lp64, ilp64, ...
;;;     big-endian, little-endian
;;;     <name> of this implementation, e.g. fantastic-scheme
;;;     <name-version> of this implementation, e.g. fantastic-scheme-1.0
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (larceny:get-feature name)
  (let ((probe (assq name (system-features))))
    (and probe (cdr probe))))

(define (larceny:name-of-this-implementation)
  'larceny)

(define (larceny:name-of-this-implementation-version)
  (let* ((major (larceny:get-feature 'larceny-major-version))
         (minor (larceny:get-feature 'larceny-minor-version))
         (s (string-append
             (symbol->string (larceny:name-of-this-implementation))
             "-"
             (number->string major)
             "."
             (number->string minor))))
    s))

;;; FIXME: keep this in sync with src/Lib/Common/system-interface.sch

(define (larceny:evaluate-feature feature)
  (define (complain)
    (assertion-violation 'cond-expand "malformed feature requirement" feature))
  (define (boolean x) (if x #t #f))
  (cond ((symbol? feature)
         (case feature
          ((r7rs)
           ;; Should ERR5RS mode count as R7RS?
           (boolean (memq (larceny:get-feature 'execution-mode)
                          '(r7rs err5rs))))
          ((larceny exact-closed exact-complex ieee-float ratios)
           #t)
          ((larceny-0.98 larceny-0.99 larceny-2.0)
           ;; FIXME: should strip off trailing beta version, etc
           (let* ((major (larceny:get-feature 'larceny-major-version))
                  (minor (larceny:get-feature 'larceny-minor-version))
                  (s (string-append "larceny-"
                                    (number->string major)
                                    "."
                                    (number->string minor))))
             (string=? (symbol->string feature) s)))
          ((full-unicode)
           ;; Larceny can always represent every Unicode character,
           ;; but Unicode strings are a different story.
           (eq? (larceny:get-feature 'char-representation) 'unicode))
          ((posix)
           (boolean (member (larceny:get-feature 'os-name)
                            '("SunOS"
                              "Linux"    ; close enough
                              "MacOS X"  ; close enough
                              ))))
          ((windows)
           (eq? (larceny:os) 'windows))
          ((unix)
           (eq? (larceny:os) 'unix))
          ((darwin)
           (string=? (larceny:get-feature 'os-name) "MacOS X"))
          ((gnu-linux)
           (string=? (larceny:get-feature 'os-name) "Linux"))
          ((i386 ilp32)
           (boolean (member (larceny:get-feature 'arch-name)
                            '("X86-NASM" "IAssassin"))))
          ((ppc)
           ;; Petit Larceny runs on the PowerPC but doesn't know it.
           #f)
          ((arm)
           (string=? (larceny:get-feature 'arch-name)
                     "ARM"))
          ((sparc)
           (string=? (larceny:get-feature 'arch-name)
                     "SPARC"))
          ((clr)
           (string=? (larceny:get-feature 'arch-name)
                     "CLR"))
          ((llvm lp64 ilp64)
           ;; Sadly.
           #f)
          ((big-endian)
           (eq? (larceny:get-feature 'arch-endianness) 'big))
          ((little-endian)
           (eq? (larceny:get-feature 'arch-endianness) 'little))
          (else
           (or (eq? feature (larceny:name-of-this-implementation))
               (eq? feature (larceny:name-of-this-implementation-version))))))
        ((pair? feature)
         (case (car feature)
          ((library)
           (cond ((or (null? (cdr feature))
                      (not (null? (cddr feature))))
                  (complain))
                 ((not (list? (cadr feature)))
                  (complain))
                 (else
                  (let* ((libname (cadr feature))
                         (fname (larceny:find-r6rs-library (cadr feature))))
                    (and fname
                         (larceny:find-r6rs-library-really? libname fname))))))
          ((and)
           (if (null? (cdr feature))
               #t
               (and (larceny:evaluate-feature (car feature))
                    (larceny:evaluate-feature `(and ,@(cdr feature))))))
          ((or)
           (if (null? (cdr feature))
               #f
               (or (larceny:evaluate-feature (car feature))
                   (larceny:evaluate-feature `(and ,@(cdr feature))))))
          ((not)
           (cond ((or (null? (cdr feature))
                      (not (null? (cddr feature))))
                  (complain))
                 (else
                  (not (larceny:evaluate-feature (car feature))))))
          (else (complain))))
        (else (complain))))

(define (larceny:interpret-cond-expand clauses)

  ;; FIXME: the form is partly syntax, so this won't do much good.

  (define (complain)
    (assertion-violation 'cond-expand "malformed cond-expand"
                         (cons 'cond-expand clauses)))

  (let loop ((clauses clauses))
    (cond ((null? clauses)
           '())
          ((or (not (list? (car clauses)))
               (not (pair? (car clauses))))
           (complain))
          ((larceny:evaluate-feature (caar clauses))
           (cdr (car clauses)))
          (else
           (loop (cdr clauses))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define *standard-feature-keywords*
  '(r7rs
    exact-closed
    exact-complex
    ieee-float
    full-unicode
    ratios
    posix
    windows
    unix darwin gnu-linux bsd freebsd solaris
    i386 x86-64 ppc sparc jvm clr llvm
    ilp32 lp64 ilp64
    big-endian little-endian))

(define (larceny:features)
  (let ((standard-features
         (filter larceny:evaluate-feature *standard-feature-keywords*))
        (larceny-version
         (string->symbol (larceny:name-of-this-implementation-version))))
    (append (list (car standard-features)
                  'larceny
                  larceny-version)
            (cdr standard-features)
            (map car (larceny:available-source-libraries)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Reading of library files.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Given the name of an R7RS/R6RS library and the name of the file
;;; in which the autoloader expects to find it (based on file naming
;;; conventions, returns true if and only if the library is actually
;;; defined within the file.
;;;
;;; FIXME: for compiled files, this remains heuristic.

(define (larceny:find-r6rs-library-really? libname fname)

  (define (search-source-library-file fname)
    (call-with-input-file
     fname
     (lambda (p)
       (let loop ()
         (let ((x (read p)))
           (cond ((eof-object? x)
                  #f)
                 ((and (pair? x)
                       (memq (car x) *library-keywords*)
                       (pair? (cdr x))
                       (equal? (cadr x) libname))
                  #t)
                 (else (loop))))))))

  (cond ((file-type=? fname *slfasl-file-type*)
         (let loop ((srcnames (generate-source-names fname)))
           (cond ((null? srcnames) #f)
                 ((file-exists? (car srcnames))
                  (search-source-library-file (car srcnames)))
                 (else (loop (cdr srcnames))))))
        (else (search-source-library-file fname))))

;;; Returns an association list containing an entry for every
;;; library defined by source files found within the current
;;; require path.  Each entry is of the form
;;;
;;;     (<library> <exports> <imports> <filename> <multiple>)
;;;
;;; where
;;;
;;;     <library> is the name of a library
;;;     <exports> is its export form
;;;     <imports> is its import form
;;;     <filename> is the source file that defines the library
;;;     <multiple> is true if two distinct files define the library
;;;
;;; FIXME: symbolic links might cause spurious multiplicities.
;;;
;;; FIXME: assumes all <exports> and <imports> are declared at
;;; the top of the library or define-library form, as required
;;; by R6RS libraries.
;;;
;;; FIXME: very slow because it has to read every source file
;;; in the current require path.
;;;
;;; FIXME: the cache helps, but adding a new library file or
;;; modifying an old file should invalidate at least part of
;;; the cache.
;;;
;;; FIXME: the cache doesn't have to be thrown away when the
;;; current require path is extended; it should be possible to
;;; search only the added directories.  This would matter a
;;; lot if someone's programming style uses a lot of include
;;; declarations and also uses cond-expand a lot to test for
;;; availability of libraries.  That sounds like a likely
;;; use case.

(define *cached-source-libraries* #f)
(define *cached-require-path* '())
(define *cached-time* 0)

(define (larceny:cache-available-source-libraries! libs)
  (set! *cached-source-libraries* libs)
  (set! *cached-require-path* (current-require-path))
  (set! *cached-time* (current-seconds)))

(define (larceny:cache-of-available-source-libraries)
  (define cache-lifetime 100)
  (and (list? *cached-source-libraries*)
       (equal? *cached-require-path* (current-require-path))
       (< (- (current-seconds) *cached-time*)
          cache-lifetime)
       *cached-source-libraries*))

(define (larceny:available-source-libraries)

  (define (symbol<? sym1 sym2)
    (string<? (symbol->string sym1)
              (symbol->string sym2)))

  (define (lexicographic lib1 lib2)
    (cond ((null? lib1)
           (not (null? lib2)))
          ((null? lib2)
           #f)
          ((and (symbol? (car lib1))
                (symbol? (car lib2)))
           (or (symbol<? (car lib1) (car lib2))
               (and (eq? (car lib1) (car lib2))
                    (lexicographic (cdr lib1) (cdr lib2)))))
          ((symbol? (car lib1))
           #f)
          ((symbol? (car lib2))
           #t)
          (else
           #f)))

  (define (by-name lib1 lib2)
    (lexicographic (car lib1) (car lib2)))

  (let ((libraries-found '())          ; list of libraries found so far
        (directories-searched '()))    ; don't search these again

    (define (find-available-libraries! path)
      (if (and (larceny:directory? path)
               (not (member path directories-searched)))
          (let* ((files (larceny:list-directory path))
                 (files (larceny:sort-by-suffix-priority files)))
            (set! directories-searched
                  (cons path directories-searched))
            (parameterize ((current-directory path))
              (let loop ((files files))
                (cond ((null? files) #t)
                      (else
                       (process-file! (car files))
                       (loop (cdr files)))))))))

    (define (process-file! file)
      (cond ((larceny:directory? file)
             (find-available-libraries! file))
            ((and (exists (lambda (type) (file-type=? file type))
                          *library-suffixes-source*)
                  (larceny:contains-libraries-only? file))
             (call-with-input-file file (make-process-libraries! file)))
            (else #t)))

    (define (make-process-libraries! fname)
      (make-file-processer/preserve-reader-state
       (lambda (in)
         (do ((x (read in) (read in)))
             ((eof-object? x))
           (process-library! x fname)))))

    (define (process-library! library fname)
      (and (list? library)
           (<= 4 (length library))
           (memq (car library) *library-keywords*)
           (let ((name (cadr library))
                 (exports (caddr library))
                 (imports (cadddr library)))
             (define (okay? keyword form)
               (and (list? name)
                    (pair? name)
                    (eq? keyword (car form))))
             (and (pair? name)
                  (okay? (car name) name)
                  (okay? 'export exports)
                  (okay? 'import imports)
                  (let* ((filename (larceny:absolute-path fname))
                         (entry (list name exports imports filename #f))
                         (probe (assoc name libraries-found)))
                    (cond ((and probe (equal? probe entry))
                           #t)
                          (else
                           (set! libraries-found
                                 (cons entry libraries-found))
                           (if probe
                               (for-each mark-as-multiple!
                                         (filter (lambda (entry)
                                                   (equal? name (car entry)))
                                                 libraries-found))))))))))

    (or (larceny:cache-of-available-source-libraries)
        (begin
         (for-each find-available-libraries! (current-require-path))
         (set! libraries-found
               (list-sort by-name libraries-found))
         (larceny:cache-available-source-libraries! libraries-found)
         libraries-found))))         

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
