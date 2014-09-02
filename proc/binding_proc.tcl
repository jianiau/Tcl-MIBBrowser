bind $MIBINFO <KeyPress> break
bind $MIBINFO <Control-c> {}


# Replace default binding to make text read-only
bind $RESULT  <KeyPress> {break}


bind $RESULT <ButtonRelease-3> {
	catch {destroy $RESULT.m}
	set M [menu $RESULT.m -tearoff 0]	
	$M add checkbutton -label "Auto clear" -variable ::result_clear
	$M add command -label "Clear" -command {$RESULT delete 1.0 end}
	$M add separator
	$M add command -label "Select all" -command {
		$RESULT tag remove sel 1.0 end
		$RESULT tag add sel 1.0 end
	}
	$M add command -label "Copy" -command {tk_textCopy $RESULT}
	$M add separator
	$M add command -label "Save" -command {save_result}
	tk_popup $RESULT.m %X %Y
}

bind $RESULT <Control-c> {tk_textCopy %W}

bind $RESULT <KeyRelease-slash> {
	focus $LF_SEARCH2.en_search
	$LF_SEARCH2.en_search selection range 0 end
}



## TREE bindings

bind $TREE <ButtonRelease-3> {

	catch {destroy $TREE.m}
	menu $TREE.m -tearoff 0
	$TREE.m add command -label "snmpwalk" -command {
		::snmp::snmpwalk
	}
	$TREE.m add separator
	if {($::snmp::ACCESS==18)||($::snmp::ACCESS==19)||($::snmp::ACCESS==48)||$::TREE_DBG} {
		$TREE.m add command -label "snmpget" -command {::snmp::snmpget}
	} else {
		$TREE.m add command -label "snmpget" -state disable
	}
	
	$TREE.m add command -label "snmpgetnext" -command {
		::snmp::snmpgetnext
	}
	#puts ::snmp::ACCESS=$::snmp::ACCESS
	if {($::snmp::ACCESS==19)||($::snmp::ACCESS==20)||($::snmp::ACCESS==48)||$::TREE_DBG} {
		$TREE.m add command -label "snmpset" -command {::snmp::snmpset}
	} else {
		$TREE.m add command -label "snmpset" -command {::snmp::snmpset} -state disable
	}
	
	$TREE.m add separator
	
	if { ( ($::snmp::ACCESS==18) || ($::snmp::ACCESS==19) || ($::snmp::ACCESS==48)) && ($::snmp::TYPE=="s")||$::TREE_DBG} {
		$TREE.m add command -label "dump OCTET" -command {::snmp::snmpdump}
	} else {
		$TREE.m add command -label "dump OCTET" -state disable
	}
	
	if {($::snmp::ACCESS==19)||($::snmp::ACCESS==20)||($::snmp::ACCESS==48)||$::TREE_DBG} {
		$TREE.m add command -label "upload file" -command {::snmp::snmpupload}
	} else {
		$TREE.m add command -label "upload file" -command {} -state disable
	}
	
	$TREE.m add separator
	
	$TREE.m add command -label "Copy OID" -command {
		clipboard clear
        clipboard append -- $::snmp::OID
	}
	$TREE.m add command -label "Copy name" -command {
		clipboard clear
        clipboard append -- $::snmp::NAME
	}
	
	tk_popup $TREE.m %X %Y
	set ::TREE_DBG 0
}


$TREE notify bind $TREE <Selection> {
	if {%S!=""} {
		set name [get_node_data %S name]
		set oid [get_node_data %S oid]
		set type [get_node_data %S type]
		set access [get_node_data %S access]		
		if {$::show_mib_info} {
			if [regexp {^\d} $oid] {
				$MIBINFO delete 1.0 end 
				$MIBINFO insert end "oid $oid\n"
				$MIBINFO insert end [string range [snmp_translate -Td $oid] 1 end-1]
			}
		}
		set ::snmp::NAME $name
		set ::snmp::OID $oid
		set ::snmp::ACCESS $access
		set ::snmp::selection %S	
		set ::snmp::TYPE $::snmp::type_table($type)
	}
}


$TREE notify bind $TREE <Collapse-before>  {
	if {[catch {set prev_node [get_node_data [$TREE selection get] oid]}]} {
		set prev_node "."
	}
	set node [get_node_data %I oid]	
	if {[regexp $node $prev_node]} {
		goto_node %I
	}
}


bind $TREE <Double-Button-1> {tree_dbclick %x %y}


bind $TREE <bracketleft> {
	set ::direction up
	goto_next_match
}
bind $TREE <bracketright> {
	set ::direction down
	goto_next_match
}

bind $TREE <slash> {
	focus $LF_SEARCH.en_search
	$LF_SEARCH.en_search selection range 0 end
}

bind $TREE <Control-w> {
	::snmp::snmpwalk
}

bind $TREE <Control-n> {
	 ::snmp::snmpgetnext
}

bind $TREE <Control-g> {
	if {($::snmp::ACCESS==18)||($::snmp::ACCESS==19)} {
		::snmp::snmpget
	}
}

bind $TREE <Control-s> {
	if {($::snmp::ACCESS==19)||($::snmp::ACCESS==20)||($::snmp::ACCESS==48)} {
		::snmp::snmpset
	}
}

set ::TREE_DBG 0
bind $TREE <KeyPress-Control_L> {
	set ::TREE_DBG 1
}
bind $TREE <KeyRelease-Control_L> {
	set ::TREE_DBG 0
}


## TREE search

bind $LF_SEARCH.en_search <KeyRelease> {
	# search patten change
	if {![string eq $::snmp::searchname_buf $::snmp::searchname]} {
		set ::snmp::searchname_buf $::snmp::searchname
#		set ::snmp::selection 1
		list_search
		if {[ lsearch $::results [$TREE selection get]]<0} {
			goto_next_match
		}
	} 	
}

bind $LF_SEARCH.en_search <bracketleft> {
	set ::direction up
	goto_next_match
}

bind $LF_SEARCH.en_search <bracketright> {
	set ::direction down
	goto_next_match
}

bind $LF_SEARCH.en_search <Prior> {
	set ::direction up
	goto_next_match
}

bind $LF_SEARCH.en_search <Next> {
	set ::direction down
	goto_next_match
}

bind $LF_SEARCH.en_search <Escape> {
	focus $TREE
}

bind $LF_SEARCH.en_search <Return> {
	goto_next_match
}





## result search
set ::match_mark 0.0
bind $LF_SEARCH2.en_search <Return> {
	if { $::res_direction == "down" } {
		mark_next
	} else {
		mark_prev
	}
}

bind $LF_SEARCH2.en_search <KP_Enter> {
	if { $::res_direction == "down" } {
		mark_next
	} else {
		mark_prev
	}
}

bind $LF_SEARCH2.en_search <KeyRelease> {
	if {![string eq $::searchresult_buf $::searchresult]} {
		set ::searchresult_buf $::searchresult
		search_result
		if { $::res_direction == "down" } {
			mark_next
		} else {
			mark_prev
		}
	}		
}


bind $LF_SEARCH2.en_search <Prior> {
	set ::res_direction  up
	mark_prev
}

bind $LF_SEARCH2.en_search <Next> {
	set ::res_direction down
	mark_next
}
