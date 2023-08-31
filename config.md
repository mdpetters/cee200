+++
author = "Markus Petters"
maxtoclevel = 2
mintoclevel = 2

# Add here files or directories that should be ignored by Franklin, otherwise
# these files might be copied and, if markdown, processed by Franklin which
# you might not want. Indicate directories by ending the name with a `/`.
# Base files such as LICENSE.md and README.md are ignored by default.
ignore = ["notebooks/", "data/"]

# RSS (the website_{title, descr, url} must be defined to get RSS)
generate_rss = false
website_title = "CEE-200"
website_descr = "Course Website"
website_url   = "https://mdpetters.github.io/cee200/"
+++



\newcommand{\R}{\mathbb R}
\newcommand{\scal}[1]{\langle #1 \rangle}
\newcommand{\concept}[1]{@@concept @@title **✔ Key Concept**@@ @@content #1 @@ @@}
\newcommand{\outline}[1]{@@outline @@title **✎ Lecture Outline**@@ @@content #1 @@ @@}
\newcommand{\note}[1]{@@note @@title **✎ Note**@@ @@content #1 @@ @@}
\newcommand{\learning}[1]{@@learning @@title **⏻ Learning Objectives**@@ @@content #1 @@ @@}
\newcommand{\caution}[1]{@@warning @@title **⚠ Caution**@@ @@content #1 @@ @@}
\newcommand{\exercise}[1]{@@exercise @@title **⌨ Assignments**@@ @@content #1 @@ @@}

@def prepath = "cee200"