/*
Title: Log4ahk - Logging for AutoHotkey 

Logs given String to given device. For more details see <Log4ahk>
  
Authors:
<hoppfrosch at hoppfrosch@gmx.de>: Original

License: 
WTFPL License

=== Code
    DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
        Version 2, December 2004 

Copyright (C) 2018 Johannes Kilian <hoppfrosch@gmx.de> 

Everyone is permitted to copy and distribute verbatim or modified 
copies of this license document, and changing it is allowed as long 
as the name is changed. 

DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE 
TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION 

0 - You just DO WHAT THE FUCK YOU WANT TO.
===   
*/

; ===================================================================================
; AHK Version ...: Tested with AHK v2.0-a100-52515e2 x64 Unicode
; Win Version ...: Tested with Windows 10 Enterprise x64
; Authors ........:  * Original - deo (original)
; ...............   * Modifications - hoppfrosch 
; License .......: WTFPL (http://www.wtfpl.net/about/)
; Source ........: Original: https://autohotkey.com/board/topic/76062-ahk-l-how-to-get-callstack-solution/
; ................ V2 : https://github.com/AutoHotkey-V2/CallStack
; ===================================================================================
#include CallStack\CallStack.ahk


/*
Class: Log4ahk
A class that provides simple logging facilities for AutoHotkey

This log-Class supports 

  - <Loglevel> allows to define to a hierarchy of log messages and controls which messages are logged
  - <Layout> of the logged message
  - Appenders to the the channels to be logged to

Loglevels: 

Each message has to be logged on a certain <LogLevel>. Consider the LogLevel as the severity of the message 
you want to log: some logmessages are used for simple debug purposes, whereas other logmessages may 
indicate an Error. In some situations you want to see a very detailled logging - in other situations you just 
want to be notified about errors ... Both can be managed via <LogLevel>. 

Layout:

Layouts allow to determine the format of the messages to be logged (see <Layout>)

Appenders:

Appenders define the "channels" to be logged to. Currently following appenders can be used:

 - <AppenderStdOut> - log your messages via stdout. Using Scite4AutoHotkey or VSCode, this will be logging to console
 - <AppenderOutputDebug> - log your messages via outputDebug (you might need DbgView or a similar tool to view output)

 You might choose several appenders to be logged on simultaneously

Internals:
<Log4ahk> is implemented as singleton, so there is only one existing instance. Each change on <LogLevel>,
<Layout> will be a global change and be valid from the time of change.

Example:
=== Autohotkey ===========
#include Log4ahk.ahk

; Set the LogLevel to be filtered upon
; Show LogLevel, current function, computername and log message in log protocol
logger := Log4ahk("[%-5.5V] {%-15.15M}{%H} %m", logger.LogLevel.TRACE)
; Enable logging to STDOUT
logger.appenders.push(logger.appender.stdout())
logger.trace("TRACE - Test TRACE") 
logger.debug("TRACE - Test DEBUG")
logger.info("TRACE - Test INFO")

f1()
return

;########################################################
f1() {
	logger := Log4ahk()
	;Change the LogLevel to be filtered upon
	logger.logLevel.requiredLevel := logger.LogLevel.INFO
	logger.trace("INFO - Test TRACE") ; shouldn't be logged due to required LogLevel
	logger.debug("INFO - Test DEBUG") ; shouldn't be logged due to required LogLevel
	logger.info("INFO - Test INFO")
}

; Output: 
;[TRACE] {# }{XYZ-COMP} TRACE - Test TRACE
;[DEBUG] {# }{XYZ-COMP} TRACE - Test DEBUG
;[INFO ] {# }{XYZ-COMP} TRACE - Test INFO
;[INFO ] {f1}{XYZ-COMP} INFO - Test INFO
===
*/
class Log4ahk {
	_version := "1.0.0"
	shouldLog := 1
	appenders := []

	
	; ##########################################################################
	; --------------------------------------------------------------------------------------
	; Group: Public Methods		

	/*
	Method: trace2
	Logs the given string at TRACE2 level
	
	Parameters:
	
		str - String to be logged
	*/
	trace2(str) {
		this._log(str, LogLevel.TRACE2)
	}
	/*
	Method: trace
	Logs the given string at TRACE level
	
	Parameters:
	
		str - String to be logged
	*/
	trace(str) {
		this._log(str, LogLevel.TRACE)
	}

	/*
	Method: debug
	Logs the given string at DEBUG level
	
	Parameters:
	
		str - String to be logged
	*/
	debug(str) {
		this._log(str, LogLevel.DEBUG)
	}

	/*
	Method: info
	Logs the given string at INFO level
	
	Parameters:
	
		str - String to be logged
	*/
	info(str) {
		this._log(str, LogLevel.INFO)
	}

	/*
	Method: warn
	Logs the given string at WARN level
	
	Parameters:
	
		str - String to be logged
	*/
	warn(str) {
		this._log(str, LogLevel.WARN)
	}

	/*
	Method: error
	Logs the given string at ERROR level
	
	Parameters:
	
		str - String to be logged
	*/
	error(str) {
		this._log(str, LogLevel.ERROR)
	}

	/*
	Method: fatal
	Logs the given string at TRACE level
	
	Parameters:
	
		str - String to be logged
	*/
	fatal(str) {
		this._log(str, this.logLevel.FATAl)
	}

	; --------------------------------------------------------------------------------------
	; Group: Private Methods

	/*
	Method: _log
	Logs the given string at the given level
	
	Parameters:
	
		str - String to be logged
		loglvl - level on which the given message is to be logged
		
	Internals:
	The given LogLevel is compared against the global required fixlevel (see <required>) 
	Is the given LogLevel equal or greater the required LogLevel the logmessage is printed 
	- otherwise the logmessage is suppressed.
	*/		
	_log(str, loglvl := 2)  {
		if (!this.shouldLog)
			return

		this.logLevel.currentLevel := loglvl

		if (this.logLevel.requiredLevel <= this.logLevel.currentLevel  ) {
			placeholders := this._fillLayoutPlaceholders(str) ; Expand the Layout placeholders with current values
			layoutexpanded := this.logLayout._expand(placeholders) ; Generate the Layout string
			
			Loop this.appenders.Length {
				this.appenders[A_Index].log(layoutexpanded)
			}
		}
		return
	}
  
  	/*
	Method: _fillLayoutPlaceholders
	Fills some variables needed by <Layout> with the currently valid values. 
	
	Parameters:
	
		str - String to be logged
	*/			
	_fillLayoutPlaceholders(str := "") {
		caseSensitivMode := "On"
		tokens := this.logLayout.tokens
		ph := Map()
		thiscalldepth := 3

		; Get the current Performance counter here, to be able to activate Placeholder %r and %R anytime ...
		CounterCurr := 0
		DllCall("QueryPerformanceCounter", "Int64*", &CounterCurr)
		; Pre-Get the callstack
		cst:= CallStack(deepness := thiscalldepth+20)
		cstlength := 0
		for key, val in cst {
			cstlength := cstlength + 1
		}

		Loop tokens.Length {
			a := tokens[A_Index]
			value := ""
			if (StrCompare(a["Placeholder"], "d", caseSensitivMode) = 0) {
				value := FormatTime(, "yyyy/MM/dd hh:mm:ss")
			}
			else if (StrCompare(a["Placeholder"], "F", caseSensitivMode) = 0) {	
				value :=  cst[-thiscalldepth].file
			}
			else if (StrCompare(a["Placeholder"], "H", caseSensitivMode) = 0) {
				value := A_ComputerName
			}
			else if (StrCompare(a["Placeholder"], "i", caseSensitivMode) = 0) {	
				depth := cst[-thiscalldepth].depth
				value := ""
				loop depth
					value := value . "__"
			}
			else if (StrCompare(a["Placeholder"], "l", caseSensitivMode) = 0) {	
				value :=  cst[-thiscalldepth].function " in " cst[-thiscalldepth].file " (" value := cst[-thiscalldepth].line ")"
			}
			else if (StrCompare(a["Placeholder"], "L", caseSensitivMode) = 0) {	
				value := cst[-thiscalldepth].line
			}
			else if (StrCompare(a["Placeholder"], "m", caseSensitivMode) = 0) {
				value := str
			}
			else if (StrCompare(a["Placeholder"], "M", caseSensitivMode) = 0) {
				value := cst[-thiscalldepth].function
			}
			else if (StrCompare(a["Placeholder"], "P", caseSensitivMode) = 0) {
				value := DllCall("GetCurrentProcessId")
			}
			else if (StrCompare(a["Placeholder"], "r", caseSensitivMode) = 0) {
				value := (CounterCurr - this._CounterStart) / this._CounterFreq * 1000
			}
			else if (StrCompare(a["Placeholder"], "R", caseSensitivMode) = 0) {
				value := (CounterCurr - this._CounterPrev) / this._CounterFreq * 1000
			}
			else if (StrCompare(a["Placeholder"], "s", caseSensitivMode) = 0) {
				value := A_Scriptname
			}
			else if (StrCompare(a["Placeholder"], "S", caseSensitivMode) = 0) {
				value := A_ScriptFullPath
			}
			else if (StrCompare(a["Placeholder"], "T", caseSensitivMode) = 0) {
				iCnt := 0
				start := 0
				ende := cstlength-thiscalldepth
				if (a["curly"] != 0) {
					Pattern := "\{(\-{0,1}[0-9]{0,2})[\:]{0,1}(\-{0,1}[0-9]{0,2})\}"
    				FoundPos := RegExMatch(a["curly"], pattern, &Match) 
					iStart := 0
					iEnde := 0				
					if (Match[1]) 
						iStart := Integer(Match[1])
					if (Match[2]) 	
						iEnde := Integer(Match[2])
					if (iStart > 0)
						start := iStart
					else if (iStart < 0)
						start := ende - iStart
					if (iEnde < 0) 
						ende := ende - iEnde
					else if (iEnde > 0)
						ende := iEnde
				}
				value := ""
				for key, val in cst {
					if ((A_Index >= start ) & (A_Index <= ende)) {
						iCnt := iCnt+1
						if (iCnt > 1 )
							value := value . "=>"
		 				value := value . val.function
					}
				}
			}
			else if (StrCompare(a["Placeholder"], "V", caseSensitivMode) = 0) {
				value := this.logLevel.tr(this.logLevel.currentLevel)
			}
			
			ph[a["Placeholder_decorated"]]  := value
		}

		this._CounterPrev := CounterCurr
		return ph
	}

	static defaultLayout := "[%V] #%M# %m"
	static defaulLogLvl := LogLevel.TRACE2
	static illegalLayout := ""
	static illegalLogLvl := -1

	; Go for singleton
	static instance := 0 
	static Call(layout := Log4ahk.illegalLayout, logLvl := Log4ahk.illegalLogLvl) {
		if (Log4ahk.instance != 0) {
			if(layout != Log4ahk.illegalLayout) {
				Log4ahk.instance.logLevel.requiredLevel := logLvl
			}
			if(logLvl != Log4ahk.illegalLogLvl) {
				Log4ahk.instance.logLayout.laylout := layout
			}
			return Log4ahk.instance 
		}

		if(layout == Log4ahk.illegalLayout) {
			layout := Log4ahk.defaultLayout
		}
		if(logLvl == Log4ahk.illegalLogLvl) {
			logLvl := Log4ahk.defaulLogLvl
		}
		return super(layout, logLvl)
	}

	__New(layout, logLvl) {
		Log4ahk.instance := this

		this.logLevel := LogLevel(logLvl)
		this.logLayout := LogLayout(layout)
		this.appenders := []

		CounterStart := 0
		DllCall("QueryPerformanceCounter", "Int64*", &CounterStart)
		this._CounterStart := CounterStart
		this._CounterPrev := CounterStart
		freq := 0
		DllCall("QueryPerformanceFrequency", "Int64*", &freq)
		this._CounterFreq := freq
	}

	; ##################### Start of Properties ##############################################

	/* ########################################################################## 
	Class: Log4ahk.AppenderOutputDebug
	Helper class for <Log4ahk> (Implementing appender via outputdebug)

	Logs messages via OutputDebug	

	Usage:
	=== Autohotkey
	logger.appenders.push(Log4ahk.AppenderOutputDebug())
	===
	*/
	class AppenderOutputDebug {
		log(msg) {
			OutputDebug(msg)
		}
	}
	/* ########################################################################## 
	Class: Log4ahk.AppenderStdOut
	Helper class for <Log4ahk> (Implementing appender via stdout)

	Logs messages via StdOut	

	Usage:
	=== Autohotkey
	logger.appenders.push(Log4ahk.AppenderStdOut())
	===
	*/
	class AppenderStdOut {
		log(msg) {
			FileAppend(msg . "`n", "*")
		}
	}
	
	/* ########################################################################## 
	Class: Log4ahk.AppenderFile
	Helper class for <Log4ahk> (Implementing appender via file)

	Logs messages via file	

	Usage:
	=== Autohotkey
	logger.appenders.push(Log4ahk.AppenderFile())
	===
	*/
	class AppenderFile {
		__New(filename) {
			this.filename := filename
		}

		log(msg) {
			FileAppend(msg . "`n", this.filename)
		}
	}	
}

/* ########################################################################## 
Class: LogLayout
Helper class for <Log4ahk> (Implementing Layout)

Creates a pattern Layout according to <log4j-Layout: http://jakarta.apache.org/log4j/docs/api/org/apache/log4j/PatternLayout.html> and a couple of Log4ahk-specific extensions.

Placeholders: 

The following placeholders can be used within the Layout string:

%d - Current date in yyyy/MM/dd hh:mm:ss format
%F - File where the logging event occurred
%i - Indentationstring according calldepth of calling method
%H - Hostname
%l - Fully qualified name of the calling method followed by the callers source the file name and line number between parentheses.
%L - Line number within the file where the log statement was issued
%m - The message to be logged
%M - Method or function where the logging request was issued
%P - pid of the current process
%r - Number of milliseconds elapsed from logging start to current logging event
%R - Number of milliseconds elapsed from last logging event to current logging event 
%s - Name of the current script
%S - Fullpath of the current script
%T - Stack trace of the function called
%V - Log level

Quantify Placeholders:

Most placeholders can be extended with formatting instructions, just similar to <format: https://lexikos.github.io/v2/docs/commands/Format.htm>:

%20M - Reserve 20 chars for the method, right-justify and fill with blanks if it is shorter
%-20M - Same as %20c, but left-justify and fill the right side with blanks
%09r - Zero-pad the number of milliseconds to 9 digits
%.8M - Specify the maximum field with and have the formatter cut off the rest of the value


Fine tuning with curlies: 

Some placeholders have special functions defined if you add curlies with content after them:

%T - complete Stack Trace of the function called
%T{3:} - Stack Trace starting at depth 3, ending at maximum depth (maximum depth is the function called)
%T{3:4} - Stack Trace starting at depth 3, ending at depth 4
%T{-3:} - Stack Trace starting 3 from maximum depth, ending at maximum depth
%T{:-4}  - Stack Trace starting at mimumum depth, ending 4 from maximum depth
%T{:} - complete Stack Trace (equivalent to %T)

Usage:
=== Autohotkey
LogLayout("[%-5.5V] {%-15.15M}{%H} %m")
===
*/
class LogLayout {

	_tokens := []

	; --------------------------------------------------------------------------------------
	; Group: Private Methods
	
	/*
	Method: _expand
	Expands the placeholders with the values from the given array
	
	Parameters:
		ph - associative Array containing mapping placeholder to its replacement
	*/
	_expand(ph) {
		str := this.layout
		Loop this.tokens.Length {
			PlaceholderExpanded := ph[this._tokens[A_Index]["Placeholder_decorated"]]
			if (this._tokens[A_Index]["Quantifier"]) {
				FormatQuantify := "{1:" this._tokens[A_Index]["Quantifier"] "s}"
				PlaceholderExpanded := Format(FormatQuantify, PlaceholderExpanded)
			}
			PatternExpanded := PlaceholderExpanded
			str := RegExReplace(str, this._tokens[A_Index]["Pattern"], PatternExpanded)
						}
		return str
	}

	__New(layoutString) {
		this.layout := layoutString
	}

	/*
	Method: _split
	Splits the Layout into its tokens

	Internals:
	The Layout string is separated into its separate Layout elements (tokens). For example "%8V %M" 
	consists of two tokens: "%8V" and "%M". Each token starts with "%" and ends at the next space. 

	The tokens are split up into its separate parts: each token consists of three parts:
	
	Quantifier - All placeholders can be extended with formatting instructions, just similar to <format: https://lexikos.github.io/v2/docs/commands/Format.htm>
	Placeholder - Placeholders are replaced with the corresponding information
	Curlies - Curlies allow further manipulation of the placeholders

	As a result of the function, the property <tokens> is filled with objects, which contain the complete token as well as its single parts.

	For more information, which values are allowed for quantifiers, placeholders and curlies have a look at documentation
	of class <Layout>
	*/
	_split() {
		FoundPos := 1
		len := 0
		this._tokens := []

		haystack := this.layout
		Pattern := "(%([-+ 0#]?[0-9]{0,3}[.]?[0-9]{0,3})([diFHlLmMPrRsSTV]{1})(\{\-{0,1}[0-9]{0,2}[\:]{0,1}\-{0,1}[0-9]{0,2}\})?)"
		While (FoundPos := RegExMatch(haystack, pattern, &Match, FoundPos + len)) {
			len := Match.len(0)
			token := Map()
			token["Pattern"] := Match[1] 
			token["Quantifier"] := Match[2] 
			placeholder := Match[3]
			token["Placeholder"] := placeholder
			; Lowercase Placeholders are decorated with a leading underscore
			; This is neccessary due to case-insensitivity of keys in associative arrays in AutoHotkey
			placeholder := RegExReplace(placeholder, "([a-z]{1})" , "_" "$1")
			token["Placeholder_decorated"] := placeholder
			token["Curly"] := Match[4] 	 
			this._tokens.Push(token)
		}
	}

	; --------------------------------------------------------------------------------------
	; Group: Properties
	
	/*
	Property: layout [get/set] 
	Get/set the layout. This layout will be used to format the logged message.
	*/
	layout {
		get {
			return  this._layout
		}
		set {
			this._layout := value
			this._split()
			return value
		}
	}

	/*
	Property: tokens [get] 
	Get the tokens of the current Layout
	
	For more information see <_split>
	*/
	tokens {
		get {
			this._split()
			return  this._tokens
		}
	}
}

/* ########################################################################## 
Class: LogLevel
Helper class for <Log4ahk> (Implementing loglevels)

Loglevels support the following needs

	- prioritize your log messages due to importance of the log message (from TRACE to FATAL)
	- control which level of log messages are currently to be logged

Internals:
	- Different priorities/hierarchical loglevels are supported
	- The priorities are *trace* (1) <- *debug* (2) <- *info* (3) <- *warn* (4) <- *error* (5) <- *fatal* (6)
	- to log with a certain priority, separate methods are available (<trace>, <debug>, <info>, <warn>, <error>, <fatal>)
	- To filter messages due currently desired LogLevel, set the property logger.logLevel.requiredLevel to the required LogLevel
*/
class LogLevel {
	STATIC TRACE2 := 1
	STATIC TRACE := 2
	STATIC DEBUG := 3
	STATIC INFO := 4
	STATIC WARN := 5
	STATIC ERROR := 6
	STATIC FATAL := 7

	; --------------------------------------------------------------------------------------
	; Group: Private Methods		

	/*
	Method: tr
	Translate the numeric LogLevel into a string

	Parameters:

	lvl - Numerical LogLevel
	
	Returns:
	String describing the choosen LogLevel (to be used within <Layout>)
	*/
	tr(lvl){
		translation := ["TRACE2","TRACE","DEBUG","INFO","WARN","ERROR","FATAL"]
		if ((lvl >= LogLevel.TRACE2) & (lvl <= LogLevel.FATAL)) {
			return translation[lvl]
		}
		return "LOG"
	}

	__New(lvl := 2) {
		this.requiredLevel := lvl
		this.currentLevel := lvl
	}

	/*
	Method: _limit
	Validate the LogLevel

	Parameters:

	lvl - LogLevel to be checked
	
	Returns:
	corrected LogLevel
	*/
	_limit(lvl) {
		if (lvl < LogLevel.TRACE2) {
			return LogLevel.TRACE2
		}
		if (lvl > LogLevel.FATAL) {
			return LogLevel.FATAL
		}
		return lvl
	}

	; --------------------------------------------------------------------------------------
	; Group: Properties
	/* ---------------------------------------------------------------------------------------
	Property: currentLevel [get/set] 
	get/set the currentLevel LogLevel
	*/
	currentLevel {
		get {
			return  this._currentLevelLevel
		}
		set {
			this._currentLevelLevel := this._limit(value)
			return this._currentLevelLevel
		}
	}

	/* ---------------------------------------------------------------------------------------
	Property: requiredLevel [get/set] 
	get/set the requiredLevel LogLevel
	
	If a message is reuested to be logged, the <currentLevel> LogLevel is compared against requiredLevel LogLevel.
	If the currentLevel LogLevel is greater/equal the requiredLevel LogLevel the message is logged - otherwise it is suppressed
	*/
	requiredLevel {
		get {
			return  this._requiredLevelLevel
		}
		set {
			this._requiredLevelLevel := this._limit(value)
			return this._requiredLevelLevel
		}
	}
}