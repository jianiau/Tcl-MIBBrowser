#!/usr/bin/wish

set appPath [file normalize [info script]]
if {[file type $appPath] == "link"} {set appPath [file readlink $appPath]}
set appPath [file dirname $appPath]

set confPath [file join $env(HOME) .TCl-MIBBrowser]

file mkdir [file join $confPath profile]
file mkdir [file join $confPath dumpfile]
file mkdir [file join $confPath macro]

#if [file exist $confPath]
#if {[namespace exists ::vfs]} {
#	set confPath [file dirname $appPath]
#} else {
#	set confPath $appPath
#}

lappend ::auto_path [file join $appPath lib]

package require Tk
package require netsnmptcl
package require treectrl
package require inifile
package require bigint
package require sha1
package require ip



namespace eval ::snmp {}
namespace eval ::macro {}
source [file join $appPath proc PBKDF2.tcl]
source [file join $appPath proc MIB_browser_proc.tcl]
source [file join $appPath proc dialog.tcl]
source [file join $appPath proc icons.tcl]
source [file join $appPath proc keynav.tcl]


# set init value
set ::snmp::app snmp_getnext
set ::snmp::IPv6 0
set ::snmp::ver 2c
set ::snmp::comm_r public
set ::snmp::comm_w private
set ::snmp::timeout 1
set ::snmp::retry 0
set ::snmp::port 161
set ::snmp::bulkget 1
set ::snmp::MIBDIRS $env(HOME)/.snmp/mibs
set ::snmp::output 3
set ::snmp::useroutput -OQsxt
set ::snmp::agentip 192.168.100.1
set ::snmp::cmd ""
set ::snmp::homeiplist ""
set ::snmp::usm "docsisManager"
set ::snmp::level noAuthNoPriv
set ::snmp::authtype md5
set ::snmp::authpw ""
set ::snmp::authkey ""
set ::snmp::privtype des
set ::snmp::privpw ""
set ::snmp::privkey ""
set ::snmp::authkeytype "key"
set ::snmp::privkeytype "key"
set ::snmp::useDH 0
set ::snmp::DHKey ""
set ::snmp::DHInit 0
set ::snmp::TREE_DSP_TYPE 2
# search init
set ::snmp::searchname	""
set ::search_fullmatch 0
set ::search_case 0
set ::direction down
set ::replace_macro_addr 1
# font
ttk::style configure My.TRadiobutton -font {"DejaVu Sans Mono" 9 {}}
set ::tree_font   {"Droid Sans" 12 normal}
set ::info_font   {"Droid Sans" 10  normal}
set ::result_font {"Droid Sans" 12 normal}

set ::show_mib_info 1
set ::result_clear 1

set ::function_key_num 8
for {set i 1} {$i<=$::function_key_num} {incr i} {
	set ::quick(F$i.name) "F$i"
	set ::quick(F$i.cmd) ""
}
# update value via inifile



if [file exist $confPath/config.ini] {
	set inifd [::ini::open $confPath/config.ini r]
	catch {
	foreach key [ ::ini::keys $inifd snmp] {
		set ::snmp::$key [ ::ini::value $inifd snmp $key]
	}}
	catch {
	foreach key [ ::ini::keys $inifd global] {
		set ::$key [ ::ini::value $inifd global $key]
	}}
	catch {
	foreach key [ ::ini::keys $inifd quick] {
		set ::quick($key) [ ::ini::value $inifd quick $key]
	}}
	::ini::close $inifd
}



wm title . "Tcl-MIBBrowser"
wm withdraw .
wm transient .
wm protocol . WM_DELETE_WINDOW {
	ttk::dialog .saveFileDialog -title "Save file?" \
		-icon question -message "Save file before closing?" \
		-detail "If you do not save the file, your work will be lost" \
		-buttons [list yes no ] \
		-labels [list yes "Save file" no "Don't save"] \
		-command save_config
	vwait ::exist_TCLMIB	
	#set reply [tk_dialog .foo "Exit" "Save settings to config.ini ?" "" "" Yes No]	
	#if {$reply==0} {
	#	set inifd [::ini::open $confPath/config.ini w+]
	#	foreach key {timeout retry MIBDIRS output useroutput IPv6 agentip ver comm_r comm_w usm level \
	#				authtype authpw authkey authkeytype\
	#				privtype privpw privkey  privkeytype useDH DHKey } {
	#		::ini::set $inifd snmp $key [set ::snmp::$key]
	#	}
	#	foreach key {tree_font info_font result_font show_mib_info result_clear replace_macro_addr} {
	#		::ini::set $inifd global $key [set ::$key]
	#	}
	#	for {set i 1} {$i<=$::function_key_num} {incr i} {
	#		::ini::set $inifd quick F$i.name [$TOOL_BAR.bt_quickF$i cget -text]
	#		::ini::set $inifd quick F$i.cmd  [$TOOL_BAR.bt_quickF$i cget -command]
	#	}
	#	::ini::commit $inifd
	#	::ini::close $inifd
	#}
	
#	save_bookmark
	destroy .
	exit
}


proc save_config {res} {
	global confPath TOOL_BAR
	switch $res {
		"yes" {
			set inifd [::ini::open $confPath/config.ini w+]
			foreach key {timeout retry MIBDIRS output useroutput IPv6 agentip ver comm_r comm_w usm level \
						authtype authpw authkey authkeytype\
						privtype privpw privkey  privkeytype useDH DHKey } {
				::ini::set $inifd snmp $key [set ::snmp::$key]
			}
			foreach key {tree_font info_font result_font show_mib_info result_clear replace_macro_addr} {
				::ini::set $inifd global $key [set ::$key]
			}
			for {set i 1} {$i<=$::function_key_num} {incr i} {
				::ini::set $inifd quick F$i.name [$TOOL_BAR.bt_quickF$i cget -text]
				::ini::set $inifd quick F$i.cmd  [$TOOL_BAR.bt_quickF$i cget -command]
			}
			::ini::commit $inifd
			::ini::close $inifd		
		}
		"no" {
		}
	}
	set ::exist_TCLMIB 1
}

for {set i 0} {$i<=27} {incr i} {
	switch $i {
		1  {set ::snmp::type_table($i) o}
		2  {set ::snmp::type_table($i) s}
		3  {set ::snmp::type_table($i) i}
		4  {set ::snmp::type_table($i) a}
		5  {set ::snmp::type_table($i) a}
		
		7  {set ::snmp::type_table($i) u}
		8  {set ::snmp::type_table($i) t}
		
		12 {set ::snmp::type_table($i) b}
		
		14 {set ::snmp::type_table($i) u}
		15 {set ::snmp::type_table($i) u}
		16 {set ::snmp::type_table($i) i}
		default {set ::snmp::type_table($i) others}
	}
}
unset i


#option add *Menu.background [ttk::style configure . -background]
#option add *Menu.activeBackground [ttk::style configure . -selectbackground]
#option add *Menu.activeForeground [ttk::style configure . -background]


## menu
menu .mbar -type menubar
.mbar add cascade -label "File"
.mbar add cascade -label "Option" -menu .mbar.option
.mbar add cascade -label "View" -menu .mbar.view
.mbar add cascade -label "Result" -menu .mbar.result
.mbar add cascade -label "Macro" -menu .mbar.macro
.mbar add cascade -label "Theme" -menu .mbar.theme

# option menu
menu .mbar.option -tearoff 0
.mbar.option add cascade -label "Search" -menu .mbar.option.search
if {$tcl_version >= 8.6} {
	.mbar.option add separator
	.mbar.option add command -label "Font" -command {font_setup}
}

menu .mbar.option.search -tearoff 0
.mbar.option.search add checkbutton -label "Case Sensitive" -variable ::search_case
.mbar.option.search add checkbutton -label "Exact Match" -variable ::search_fullmatch

# view menu
menu .mbar.view -tearoff 0
.mbar.view add checkbutton -label "Show MIB Info" -variable ::show_mib_info -command {
	if {$::::show_mib_info} {
		grid $LF_MIBINFO -row 0 -column 0 -sticky we
	} else {
		grid forget $LF_MIBINFO
	}
}

# Result menu
menu .mbar.result -tearoff 0
.mbar.result add checkbutton -label "Auto clear" -variable ::result_clear
.mbar.result add command -label "Clear" -command {$RESULT delete 1.0 end}
.mbar.result add separator
.mbar.result add command -label "Select all" -command {
	$RESULT tag remove sel 1.0 end
	$RESULT tag add sel 1.0 end
}
.mbar.result add command -label "Copy" -command {tk_textCopy $RESULT}
.mbar.result add separator
.mbar.result add command -label "Save" -command {save_result}


# Macro menu
set ::start_macro_record 0
set ::macro_cmds ""

menu .mbar.macro -tearoff 0
.mbar.macro add cascade -label "Record"  -menu .mbar.macro.record
menu .mbar.macro.record -tearoff 0
.mbar.macro.record add command -label "Start" -command {	
	.mbar.macro.record entryconfigure 0 -state disable
	.mbar.macro.record entryconfigure 1 -state normal
	set ::start_macro_record 1
	set ::macro_cmds ""
}
.mbar.macro.record add command -label "Stop"  -command {
	.mbar.macro.record entryconfigure 0 -state normal
	.mbar.macro.record entryconfigure 1 -state disable
	macro_gui
	set ::start_macro_record 0	
} -state disable
.mbar.macro add command -label "Run Macro" -command {run_macro}
.mbar.macro add checkbutton -label "Replace Macro IP" -variable ::replace_macro_addr

# Theme menu
foreach name [ttk::themes] {
    if {![info exists ::THEMES($name)]} {
	lappend THEMELIST $name [set ::THEMES($name) [string totitle $name]]
    }
}




menu .mbar.theme -tearoff 0
foreach {theme name} $::THEMELIST {
	.mbar.theme add radiobutton -label $name \
		-variable ::ttk::currentTheme -value $theme \
		-command [list ttk::setTheme $theme]
}

.mbar add cascade -label "Help"
. configure -menu .mbar


## main 
set TOOL_BAR [ttk::frame .fr_toolbar -relief groove]


# reserve : currently use frame, if need more tab will use notebook
#set NB [ttk::notebook .nb]
set NB [ttk::frame .nb]

# reserve : STATUS_BAR in bottom to show some info
#set STATUS_BAR [ttk::frame .fr_statusbar]

grid $TOOL_BAR -sticky we
grid $NB -sticky news
#grid $STATUS_BAR -sticky we 

grid columnconfigure . 0 -weight 1
grid rowconfigure . 1 -weight 1


#ttk::style configure My.TRadiobutton -font {"DejaVu Sans Mono" 9 {}}
## Tool bar
ttk::button  $TOOL_BAR.bt_protocol -text "SNMP Setting" -command snmp_protocol
ttk::button  $TOOL_BAR.bt_mibtree  -text "MIB Setting"  -command mib_setup
ttk::separator $TOOL_BAR.sep -orient vertical
for {set i 1} {$i<=$::function_key_num} {incr i} {
	ttk::button  $TOOL_BAR.bt_quickF$i  -text $::quick(F$i.name)  -command $::quick(F$i.cmd)
}



pack  $TOOL_BAR.bt_protocol -padx 5 -pady 5 -anchor w -side left
pack  $TOOL_BAR.bt_mibtree  -padx 5 -pady 5 -anchor w -side left
pack  $TOOL_BAR.sep -fill y -padx 5 -pady 5 -anchor w -side left
for {set i 1} {$i<=$::function_key_num} {incr i} {
	pack  $TOOL_BAR.bt_quickF$i -ipadx 5 -padx 5 -pady 5 -anchor w -side left
}
#pack  $TOOL_BAR.lb_status   -padx 10 -pady 0 -anchor e -side right
## end tool bar


## NB
set QUERY [ttk::frame .nb.query]
#.nb add $QUERY -text "Query"
## end NB

grid $QUERY -stick news
grid rowconfigure $NB  0 -weight 1
grid columnconfigure $NB 0 -weight 1

## status bar
#ttk::label $STATUS_BAR.lb_oid 
#pack $STATUS_BAR.lb_oid -anchor w -expand 1
## end status bar



## Query tab
#  ======================================
# | SMMP agent |  SNMP command           |
# ========================================
# |  Tree      |      info               |
# |            |                         |
# |            |=========================|
# |            |                         |
# |            |      result             |
# |============|=========================|
# |  search    |     search              |
# ========================================

set LF_AGENT  [ttk::labelframe $QUERY.lf_agent -text "SMMP agent"]
set LF_CMD    [ttk::labelframe $QUERY.lf_cmd   -text "SNMP command"]
set PW [ttk::panedwindow $QUERY.pw -orient horizontal]
grid $LF_AGENT  -row 0 -column 0 -sticky news -padx 5 -pady 5
grid $LF_CMD    -row 0 -column 1 -sticky news -padx 5 -pady 5
grid $PW -columnspan 2 -sticky news -padx 5 -pady 5
grid columnconfigure $QUERY 1 -weight 1  
grid rowconfigure $QUERY 1 -weight 1 


ttk::frame $PW.fr_left
ttk::frame $PW.fr_right
$PW insert end $PW.fr_left  -weight 2;#-width 500 ;#-weight 900
$PW insert end $PW.fr_right -weight 1


set LF_TREE    [ttk::labelframe $PW.fr_left.lf_tree   -text "MIB tree"]
set LF_SEARCH  [ttk::labelframe $PW.fr_left.lf_search -text "Search"]
grid $LF_TREE   -row 0 -column 0 -sticky news
grid $LF_SEARCH -row 1 -column 0 -sticky we
grid columnconfig $PW.fr_left 0 -weight 1
grid rowconfig $PW.fr_left 0 -weight 1


set LF_MIBINFO [ttk::labelframe $PW.fr_right.lf_mibinfo -text "MIB Info"]
set LF_RESULT  [ttk::labelframe $PW.fr_right.lf_result  -text "Result"]
set LF_SEARCH2 [ttk::labelframe $PW.fr_right.lf_search  -text "Search"]
if {$::show_mib_info} {
grid $LF_MIBINFO -row 0 -column 0 -sticky we
}
grid $LF_RESULT   -row 1 -column 0 -sticky news
grid $LF_SEARCH2  -row 2 -column 0 -sticky news
grid columnconfig $PW.fr_right 0 -weight 1
grid rowconfig $PW.fr_right 1 -weight 1



# Query tab ,top frame
ttk::checkbutton $LF_AGENT.ckb_ip -text "IPv6" -variable ::snmp::IPv6 -command {
	set ::snmp::cmd "$::snmp::app [::snmp::cmdopt] [::snmp::outfmt] [::snmp::addr] $::snmp::OID"
}	
ttk::entry $LF_AGENT.en_ip -textvariable ::snmp::agentip -width 32
pack $LF_AGENT.ckb_ip $LF_AGENT.en_ip -side left -fill both -padx 5

ttk::entry $LF_CMD.en_cmd -textvariable ::snmp::cmd 
set ::snmp::cmd ""
ttk::button $LF_CMD.bt_cmd -text "Run" -command {run_cmd $::snmp::cmd}

pack $LF_CMD.en_cmd -fill both -side left -expand 1 -padx 5 
pack $LF_CMD.bt_cmd -side right


# Query tab ,Tree frame
# load mibtree ui
source [file join $appPath proc tree_treectrl.tcl]

## Query tab ,search frame
grid columnconfig $LF_SEARCH 0 -weight 1

ttk::entry       $LF_SEARCH.en_search -textvariable ::snmp::searchname -validate key -validatecommand "check_search_input %S"
ttk::radiobutton $LF_SEARCH.rb_up   -text "Up"   -value up   -variable ::direction 
ttk::radiobutton $LF_SEARCH.rb_down -text "Down" -value down -variable ::direction 
#ttk::button      $LF_SEARCH.bt_search -text "Go" -command {search_cmd}

set ::snmp::searchname_buf $::snmp::searchname

proc check_search_input {key} {
	#puts key=$key
	#return 1
	if {[regexp {[\.0-9a-zA-Z]} $key]} {
		return 1
	}	
	return 0
}




grid $LF_SEARCH.en_search -row 0 -column 0 -sticky we -padx 5
grid $LF_SEARCH.rb_up     -row 0 -column 1 -sticky we -padx 5
grid $LF_SEARCH.rb_down   -row 0 -column 2 -sticky we -padx 5
#grid $LF_SEARCH.bt_search -row 0 -column 3 -sticky we -padx 5
set RESULT [text $LF_RESULT.text -wrap none  -font $::result_font]
set SH_RESULT [::ttk::scrollbar $LF_RESULT.sh -orient horizontal -command [list $RESULT xview]]
set SV_RESULT [::ttk::scrollbar $LF_RESULT.sv -orient vertical   -command [list $RESULT yview]]
$RESULT configure -yscrollcommand [list $SV_RESULT set]
$RESULT configure -xscrollcommand [list $SH_RESULT set] 
grid $RESULT $SV_RESULT -sticky "news"
grid $SH_RESULT -columnspan 2 -sticky "we"
grid rowconfigure $LF_RESULT 0 -weight 1
grid columnconfigure $LF_RESULT 0 -weight 1


set MIBINFO [text $LF_MIBINFO.text -wrap none  -font $::info_font -height 8]
set SH_MIBINFO [::ttk::scrollbar $LF_MIBINFO.sh -orient horizontal -command [list $MIBINFO xview]]
set SV_MIBINFO [::ttk::scrollbar $LF_MIBINFO.sv -orient vertical   -command [list $MIBINFO yview]]
$MIBINFO configure -yscrollcommand [list $SV_MIBINFO set]
$MIBINFO configure -xscrollcommand [list $SH_MIBINFO set] 


set ::searchresult ""
set ::res_direction  down
ttk::entry       $LF_SEARCH2.en_search -textvariable ::searchresult
set ::searchresult_buf ""
#-validate key -validatecommand "check_search_input %S"

ttk::radiobutton $LF_SEARCH2.rb_up   -text "Up"   -value up   -variable ::res_direction 
ttk::radiobutton $LF_SEARCH2.rb_down -text "Down" -value down -variable ::res_direction
#ttk::button      $LF_SEARCH2.bt_search -text "Go" -command {search_result}
grid $LF_SEARCH2.en_search -row 0 -column 0 -sticky we -padx 5
grid $LF_SEARCH2.rb_up     -row 0 -column 1 -sticky we -padx 5
grid $LF_SEARCH2.rb_down   -row 0 -column 2 -sticky we -padx 5
#grid $LF_SEARCH2.bt_search -row 0 -column 3 -sticky we -padx 5



grid $MIBINFO $SV_MIBINFO -sticky "news"
grid $SH_MIBINFO -columnspan 2 -sticky "we"
grid columnconfigure $LF_MIBINFO 0 -weight 1
grid rowconfigure $LF_MIBINFO 0 -weight 1
grid columnconfig $LF_SEARCH2 0 -weight 1

## end Query tag

#update
source [file join $appPath proc binding_proc.tcl]


set width  [expr int([winfo screenwidth  .]*0.8)]
set height [expr int([winfo screenheight .]*0.8)]
set x [expr int([winfo screenwidth  .]*0.1)]
set y [expr int([winfo screenheight .]*0.1)]

wm geometry . ${width}x${height}+0+0
#wm geometry . 1200x675+0+0
wm deiconify .
snmp_loadmib -mall -M$::snmp::MIBDIRS 2>trtrtr
snmp_translate -TZ -f[file join $confPath translate_output.txt]
buildtree
#$TREE selection add 1
goto_node $NODE(1)
change_tree_dsp
focus $TREE


$RESULT tag configure err -foreground red
$RESULT tag configure blue -foreground blue
$RESULT tag configure match -background yellow
$RESULT tag configure mark -background orange
$RESULT tag raise mark match
$RESULT tag configure sel -background [ttk::style configure . -selectbackground] -foreground [ttk::style configure . -selectforeground]
$RESULT tag raise sel
$MIBINFO tag configure sel -background [ttk::style configure . -selectbackground] -foreground [ttk::style configure . -selectforeground]
set ::results ""



# 
proc ::tk::FirstMenu w {}

