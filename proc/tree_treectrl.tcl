set TREE [treectrl $LF_TREE.t 	-bg white \
		-highlightthickness 0 \
		-selectmode single \
		-relief groove \
		-showroot no \
		-showline 1 \
		-showrootbutton 1 \
		-showbuttons 1 \
		-showheader 0 \
		-scrollmargin 0 \
		 ]
set columnID [$TREE column create]
$TREE configure -treecolumn $columnID

listbox .listbox
set SystemHighlight [.listbox cget -selectbackground]
set SystemHighlightText [.listbox cget -selectforeground]


$TREE element create elemRect rect -fill [list $::SystemHighlight {selected}]
$TREE element create elemImage image
# $TREE element create elemImage shellicon -size small
$TREE element create elemText text  -font [list $::tree_font ""] -fill [list $::SystemHighlightText {selected}]
$TREE element create elemText2 text -font [list $::tree_font ""] -fill [list $::SystemHighlightText {selected}]
$TREE element create elemText3 text -font [list $::tree_font ""] -fill [list $::SystemHighlightText {selected}]


$TREE style create style1
$TREE style elements style1 {elemImage elemRect elemText elemText2 elemText3}
# $TREE style elements style1 { elemRect elemText elemText2}
# puts [$TREE style configure style1]
$TREE style layout style1 elemRect -union {elemText elemText2}
$TREE style layout style1 elemText -ipadx 5
$TREE style layout style1 elemText2 -ipadx 5
$TREE style layout style1 elemText3 -ipadx 5
$TREE item configure root -button yes
$TREE item style set root $columnID style1
$TREE item element configure root $columnID elemText -text "The root item"
set TREE_VS [scrollbar $LF_TREE.vs -command [list $TREE yview] -orient vertical]
set TREE_HS [scrollbar $LF_TREE.hs -command [list $TREE xview] -orient horizontal]
$TREE configure -xscrollcommand [list $TREE_HS set] -yscrollcommand [list $TREE_VS set]
grid $TREE $TREE_VS -sticky "news"
grid $TREE_HS -columnspan 2 -sticky "we"
grid rowconfigure $LF_TREE 0 -weight 1
grid columnconfigure $LF_TREE 0 -weight 1


proc buildtree {} {
	global TREE NODE columnID confPath

	if {![file exist $confPath/translate_output.txt]} {
		snmp_translate -TZ
	}
	set fd [open $confPath/translate_output.txt r]
	set data [split [read $fd] \n]
	close $fd
	add_node NODE(.) root "MIB Tree" [list "MIB Tree" "Node MIB Tree" "0" "0"]

	$TREE item element configure $NODE(.) $columnID elemText2 -text ""
#	add_node NODE(0) $NODE(.) "ccitt" [list "ccitt" 0 0 0]
#	$TREE item element configure $NODE(0) $columnID elemText2 -text "(0)"
#	$TREE item tag add $NODE(0) ccitt
	add_node NODE(1) $NODE(.) "iso"   [list "iso" 1 0 0]
	$TREE item element configure $NODE(1) $columnID elemText2 -text "(1)"
#	$TREE item tag add $NODE(1) iso
	foreach subtree $data {
		if {$subtree==""} {continue}
		if {[lindex $subtree 1]=="0.0"} {continue} 
		regexp {(.+)\.} [lindex $subtree 1] match parents
		set name [lindex $subtree 0]
		set oid  [lindex $subtree 1]		
		regexp {type=(.+)} [lindex $subtree 2] match type
		regexp {access=(.+)} [lindex $subtree 3] match access		
		add_node NODE($oid) $NODE($parents) $name [list $name $oid $type $access]
#		$TREE item tag add $NODE($oid) $name
	}
}



#define TYPE_TRAPTYPE	    20
#define TYPE_NOTIFTYPE      21
#define TYPE_OBJGROUP	    22
#define TYPE_NOTIFGROUP	    23
#define TYPE_MODID	        24
#define TYPE_AGENTCAP       25
#define TYPE_MODCOMP        26
#define TYPE_OBJIDENTITY    27

# data {"name" "oid" "type" "access"}
proc add_node {node_c node_p mibname data} {
	global TREE columnID
	upvar $node_c NODE
	set NODE [$TREE item create -button auto -open 0 -parent $node_p]	
	$TREE item style set $NODE $columnID style1
	$TREE item element configure $NODE $columnID elemText -text "$mibname" -data "$data"    
		
	set qq ""	
	regexp {.+\.(\d+)} [lindex $data 1] match qq
	$TREE item element configure $NODE $columnID elemText2 -text \($qq\)
	$TREE item element configure $NODE $columnID elemText3 -text \([lindex $data 1]\)
	# for search purpose	
	lappend ::snmp::namelist [lindex $data 0]
	#lappend ::snmp::oidlist [lindex $data 1]
}

proc goto_node {node} {
	global TREE columnID
	open_node $node
	set prev [$TREE selection get]
	if {$node != $prev} {
		$TREE selection modify $node $prev
	}

	
#	Sleep 100 
#	$TREE see $node
	TreeCtrl::SetActiveItem $TREE $node
	set ::snmp::selection [$TREE selection get 0]
}


proc open_node {node} {
	global TREE
	set nodes [$TREE item ancestors $node]
	foreach node $nodes {$TREE item expand $node}
}
proc get_node_data {node datatype} {
	global TREE columnID
	set data [$TREE item element cget $node $columnID elemText -data]
	set name [lindex $data 0]
	set oid [lindex $data 1]
	set type [lindex $data 2]
	set access [lindex $data 3]
	
	switch $datatype {
		"name" {return $name}
		"oid" {return $oid}		
		"type" {return $type}		
		"access" {return $access}		
		"all" {return [list $name $oid $type $access]}		
	}
}

# "type" {return $type}
		# "access" {return $access}
		# "ALL" {return [list $name $oid $type $access]}
		
# from DAI
proc tree_dbclick {posx posy} {
	global TREE
	set ninfo [$TREE identify $posx $posy]
	puts $ninfo
	if {[llength $ninfo] < 2} {return}
	foreach {what itemId where columnId type name} $ninfo {}
	$TREE item toggle $itemId
}

#set ::Motion_item ""
#proc tree_Motion  {posx posy} {
#	global TREE columnID
#	set ninfo [$TREE identify $posx $posy]	
#	if {[llength $ninfo] < 2} {return}	
#	foreach {what itemId where columnId type name} $ninfo {}	
#	if {$itemId==$::Motion_item} {return}
#	
#	$TREE item element configure $itemId $columnID elemBorder -background blue
#	# if {$itemId==[$TREE selection get]} {return}
#	if {$::Motion_item!=[$TREE selection get]} {
#		catch {$TREE item element configure $::Motion_item $columnID elemBorder -background white}
#	} else {
#		catch {$TREE item element configure $::Motion_item $columnID elemBorder -background gray}
#	}
#	
#	set ::Motion_item $itemId
#
#}



#define MIB_ACCESS_READONLY    18
#define MIB_ACCESS_READWRITE   19
#define	MIB_ACCESS_WRITEONLY   20
#define MIB_ACCESS_NOACCESS    21
#define MIB_ACCESS_NOTIFY      67
#define MIB_ACCESS_CREATE      48 (readcreate)



# bind $TREE <Enter> {
	# catch {destroy $TREE.l}
	# menu $TREE.l -tearoff 0
	# $TREE.l add cascade -label "Contact"
	# tk_popup $TREE.l %X %Y
# }
# bind $TREE <Motion> {
	# catch {destroy $TREE.l}
	# puts aaa
# }
