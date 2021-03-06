# Copyright (C) 2017 Harvard University, Mount Holyoke College
#
# This file is part of ProvR.
#
# ProvR is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# ProvR is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ProvR; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# This package was forked from <https://github.com/End-to-end-provenance/RDataTracker>
#
# Contact: Matthew Lau <matthewklau@fas.harvard.edu>

#-------- FUNCTIONS TO MANAGE THE GLOBAL VARIABLES--------#

# Global variables cannot be used directly in a library.  Instead, we need to
# place the variables in our own environment.  These functions make that
# environment easier to use.
.onLoad <- function(libname, pkgname) {
    .ddg.init.tables()
}

.ddg.set <- function(var, value) {
    .ddg.env[[var]] <- value
    return(invisible(.ddg.env[[var]]))
}

.ddg.is.set <- function(var) {
    return(exists(var, envir = .ddg.env))
}

.ddg.get <- function(var) {
    if (!.ddg.is.set(var)) {
        error.msg <- paste("No binding for", var, ". DDG may be incorrect!")
        .ddg.insert.error.message(error.msg)
        return(NULL)
    } else {
        return(.ddg.env[[var]])
    }
}

# .ddg.clear removes all objects from the .ddg.env environment.
.ddg.clear <- function() {
    # reinitialize tables
    .ddg.init.tables()
}

##### Mutators for specific common actions
.ddg.inc <- function(var) {
    value <- .ddg.get(var)
    .ddg.set(var, value + 1)
}

.ddg.dec <- function(var) {
    value <- .ddg.get(var)
    .ddg.set(var, value - 1)
}

.ddg.append.activity <- function(...) {
    text <- .ddg.get("ddg.activity")
    if (text != "") {
        text <- paste(text, ",\n")
    }
    .ddg.set("ddg.activity", paste(text, ..., sep = ""))
}

.ddg.append.entity <- function(...) {
    text <- .ddg.get("ddg.entity")
    if (text != "") {
        text <- paste(text, ",\n")
    }
    .ddg.set("ddg.entity", paste(text, ..., sep = ""))
}

.ddg.append.wasInformedBy <- function(...) {
    text <- .ddg.get("ddg.wasInformedBy")
    if (text != "") {
        text <- paste(text, ",\n")
    }
    .ddg.set("ddg.wasInformedBy", paste(text, ..., sep = ""))
}

.ddg.append.wasGeneratedBy <- function(...) {
    text <- .ddg.get("ddg.wasGeneratedBy")
    if (text != "") {
        text <- paste(text, ",\n")
    }
    .ddg.set("ddg.wasGeneratedBy", paste(text, ..., sep = ""))
}

.ddg.append.used <- function(...) {
    text <- .ddg.get("ddg.used")
    if (text != "") {
        text <- paste(text, ",\n")
    }
    .ddg.set("ddg.used", paste(text, ..., sep = ""))
}

.ddg.add.rows <- function(df, new.rows) {
    table <- .ddg.get(df)
    .ddg.set(df, rbind(table, new.rows))
}

.ddg.push <- function(x, value) {
    return(assign(as.character(substitute(x)), c(x, value), parent.frame()))
}

.ddg.pop <- function(x) {
    return(assign(as.character(substitute(x)), x[-length(x)], parent.frame()))
}
#-------------------BASIC FUNCTIONS-----------------------#

# .ddg.get.initial.env creates a table of non-ddg objects present in the R
# environment before the script is executed.

.ddg.get.initial.env <- function() {
    e <- globalenv()
    e.ls <- ls(e, all.names = TRUE)
    not.ddg.func <- function(name) {
        return(!grepl("ddg", name) && name != ".onLoad")
    }
    x <- Filter(not.ddg.func, e.ls)
    ddg.initial.env <- data.frame(x)
    colnames(ddg.initial.env) <- "ddg.name"
    .ddg.set("ddg.initial.env", ddg.initial.env)
}

# .ddg.init.tables creates data frames to store the initial environment,
# procedure nodes, data nodes, edges, function return values, and checkpoints. It
# also initializes selected constants and variables.  Tables are saved as
# tab-delimited files in ddg.save.

.ddg.init.tables <- function() {
    size <- 100
    .ddg.get.initial.env()
    .ddg.set("ddg.proc.nodes", data.frame(ddg.type = character(size), ddg.num = numeric(size),
        ddg.name = character(size), ddg.value = character(size), ddg.ret.linked = logical(size),
        ddg.auto.created = logical(size), ddg.time = numeric(size), ddg.snum = numeric(size),
        ddg.startLine = numeric(size), ddg.startCol = numeric(size), ddg.endLine = numeric(size),
        ddg.endCol = numeric(size), stringsAsFactors = FALSE))
    .ddg.set("ddg.data.nodes", data.frame(ddg.type = character(size), ddg.num = numeric(size),
        ddg.name = character(size), ddg.value = character(size), ddg.val.type = character(size),
        ddg.scope = character(size), ddg.from.env = logical(size), ddg.time = character(size),
        ddg.loc = character(size), ddg.current = logical(size), stringsAsFactors = FALSE))
    .ddg.set("ddg.edges", data.frame(ddg.num = numeric(size), ddg.type = character(size),
        ddg.from = character(size), ddg.to = character(size), stringsAsFactors = FALSE))
    # Create procedure and data node counters.
    .ddg.set("ddg.pnum", 0)
    .ddg.set("ddg.dnum", 0)
    .ddg.set("ddg.enum", 0)
    # Create strings used to generate the JSON file.
    .ddg.set("ddg.activity", "")
    .ddg.set("ddg.entity", "")
    .ddg.set("ddg.wasInformedBy", "")
    .ddg.set("ddg.wasGeneratedBy", "")
    .ddg.set("ddg.used", "")
    # Used to control debugging output.  If already defined, don't change its value.
    if (!.ddg.is.set("ddg.debug.lib"))
        .ddg.set("ddg.debug.lib", FALSE)
    # Used to control script debugging.
    .ddg.set("ddg.break", FALSE)
    .ddg.set("ddg.break.ignore", FALSE)
    # Used to control sourcing. If already defined, don't change its value.
    if (!.ddg.is.set("from.source"))
        .ddg.set("from.source", FALSE)
    # Set current number of checkpoints.
    .ddg.set("ddg.checkpoint.num", 0)
    # Record last command from the preceding console block.
    .ddg.set(".ddg.last.cmd", NULL)
    # Record value returned by calls to ddg.ret.  ddg.call - the string
    # representing the call, like 'f(a)'.  line - the line where the function is
    # called that is now returning ret.used - remembers if this function return
    # value has been linked to the caller.  ret.node.id - the id of the data node
    # that holds the return value.
    .ddg.set(".ddg.ret.values", data.frame(ddg.call = character(size), line = integer(size),
        ret.used = logical(size), ret.node.id = integer(size), stringsAsFactors = FALSE))
    .ddg.set(".ddg.num.returns", 0)
    # Record the current command to be opened during console execution (used when
    # executing a script using ddg.source).
    .ddg.set(".ddg.possible.last.cmd", NULL)
    # Keep track of history.
    .ddg.set(".ddg.history.timestamp", NULL)
    # Keep track of the last device seen (0 implies NULL).
    .ddg.set("prev.device", 0)
    # Store path of current script.
    .ddg.set("ddg.r.script.path", NULL)
    # Store path of current ddg.
    .ddg.set("ddg.path", NULL)
    # No ddg initialized.
    .ddg.set(".ddg.initialized", FALSE)
    # No history file.
    .ddg.set(".ddg.history.file", NULL)
    # Console is disabled.
    .ddg.set(".ddg.enable.console", FALSE)
    # Functions to be annotated.
    .ddg.set("ddg.annotate.on", NULL)
    # Functions not to be annotated.
    .ddg.set("ddg.annotate.off", NULL)
    # Script sourced with ddg.source
    .ddg.set(".ddg.is.sourced", FALSE)
    # Number of first sourced script (main script).
    .ddg.set(".ddg.next.script.num", 0)
    # Table of sourced scripts
    .ddg.set(".ddg.sourced.scripts", NULL)
    # Save debug files on debug directory
    .ddg.set("ddg.save.debug", FALSE)
    # DDGStatement number
    .ddg.set("ddg.statement.num", 0)
    # DDGStatements list
    .ddg.set("ddg.statements", list())
    # Control loop number
    .ddg.set("ddg.loop.num", 0)
    # Control loop list
    .ddg.set("ddg.loops", list())
    # Loop annotation
    .ddg.set("ddg.loop.annotate", TRUE)
    # Set max.snapshot.size for console mode.
    if (!.ddg.is.set("ddg.max.snapshot.size")) {
        .ddg.set("ddg.max.snapshot.size", 100)
    }
    # List of files read and written
    .ddg.set("ddg.infilenodes", list())
    .ddg.set("ddg.outfilenodes", list())
    # Data frame containing file reads and writes
    .ddg.set("ddg.hashtable", data.frame())
}

# Initialize the information about functions that read from files
.ddg.create.file.read.functions.df <- function() {
    # Functions that read files
    function.names <- c("source", "read.csv", "read.csv2", "read.delim", "read.delim2",
        "read.table", "read.xls", "file", "readLines")
    # The argument that represents the file name
    param.names <- c("file", "file", "file", "file", "file", "file", "xls", "description",
        "con")
    # Position of the file parameter if it is passed by position
    param.pos <- c(1, 1, 1, 1, 1, 1, 1, 1, 1)
    return(data.frame(function.names, param.names, param.pos, stringsAsFactors = FALSE))
}

.ddg.set(".ddg.file.read.functions.df", .ddg.create.file.read.functions.df())

# Initialize the information about functions that read from files
.ddg.create.file.write.functions.df <- function() {
    # Functions that read files
    function.names <- c("write.csv", "write.csv2", "write.table", "ggsave")
    # The argument that represents the file name
    param.names <- c("file", "file", "file", "filename")
    # Position of the file parameter if it is passed by position
    param.pos <- c(2, 2, 2, 1)
    return(data.frame(function.names, param.names, param.pos, stringsAsFactors = FALSE))
}

.ddg.set(".ddg.file.write.functions.df", .ddg.create.file.write.functions.df())

# Initialize the information about functions that initialize graphics devices
.ddg.create.graphics.functions.df <- function() {
    # Functions that read files
    function.names <- c("pdf", "postscript", "bmp", "jpeg", "png", "tiff", "X11")
    # The argument that represents the file name
    param.names <- c("file", "file", "filename", "filename", "filename", "filename",
        NA)
    # Position of the file parameter if it is passed by position
    param.pos <- c(1, 1, 1, 1, 1, 1, NA)
    return(data.frame(function.names, param.names, param.pos, stringsAsFactors = FALSE))
}

.ddg.set(".ddg.graphics.functions.df", .ddg.create.graphics.functions.df())

# Initialize the information about functions that update graphics
.ddg.set(".ddg.graphics.update.functions", ls(which(search() == "package:graphics")))
