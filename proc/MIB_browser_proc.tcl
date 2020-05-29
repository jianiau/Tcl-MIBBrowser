
proc Sleep {msec} {
	set _ww 0
	after $msec {
		set _ww 1
	}
	vwait _ww
}
proc log_result {msg {tag ""}} {
	global RESULT
	$RESULT insert end $msg $tag
	$RESULT see end
}
proc log_clear {} {
	global RESULT
	$RESULT delete 0.0 end
}


proc list_search {} {
	global NODE
	set i 1
	set ret ""
	
	if {$::snmp::searchname==""} {
		set ::results $ret
		return
	}	
	# if start with "." direct goto oid
	if {[regexp {^\.} $::snmp::searchname] || [regexp {\.} $::snmp::searchname]} {
		set oid [string trim $::snmp::searchname .]
		if [info exist NODE($oid)] {
			set ::results $NODE($oid)
			goto_node $NODE($oid)
		}	
		return		
	}
	foreach name $::snmp::namelist {
		if {$::search_fullmatch} {
			if {$::search_case} {
				if {[string match $::snmp::searchname $name]} {
					lappend ret $i
				}
			} else {
				if {[string match  -nocase $::snmp::searchname $name]} {
					lappend ret $i
				}
			}
		} else {
			if {$::search_case} {
				if {[regexp  $::snmp::searchname $name]} {
					lappend ret $i
				}
			} else {
				if {[regexp -nocase $::snmp::searchname $name]} {
					lappend ret $i
				}
			}
		}	
		incr i
	}
	set ::results $ret
}



proc goto_next_match {} {
	global NODE
	#list_search
	if {[llength $::results]==0} {
		puts "can not found $::snmp::searchname"
		return
	}
	if {"$::direction" == "down"} {
		foreach temp $::results {
			if {$temp>$::snmp::selection} {
				goto_node $temp
				return
			}
		}
	} else {
		set len [llength $::results]
		for {set i 0} {$i<$len} {incr i} {
			lappend re_list [lindex $::results end-$i]
		}
		foreach temp $re_list {
			if {$temp<$::snmp::selection} {
				goto_node $temp
				return
			}
		}
	}
}


proc snmp_protocol {} {
	catch {destroy .protocol}
	set p [toplevel .protocol]
	bind $p <Escape> {destroy .protocol}
	array unset ::temp
	foreach varname {ver comm_r comm_w timeout retry output useroutput} {
		set ::temp($varname) [set ::snmp::$varname]
	}
			
	wm title $p "SNMP Setting"	
	wm resizable $p 0 0
	wm transient $p [winfo toplevel [winfo parent $p]]
	ttk::labelframe $p.lf_ver -text "SNMP protocol version (-v)"
	ttk::radiobutton $p.lf_ver.rb_v1 -text "SNMPv1"  -variable ::temp(ver) -value 1
	ttk::radiobutton $p.lf_ver.rb_v2 -text "SNMPv2c" -variable ::temp(ver) -value 2c
	ttk::radiobutton $p.lf_ver.rb_v3 -text "SNMPv3"  -variable ::temp(ver) -value 3  -command {snmpv3_setup}
	
	ttk::labelframe $p.lf_comm -text "community (-c)"
	ttk::frame $p.lf_comm.fr1 ;#-relief groove
	ttk::label $p.lf_comm.fr1.lb_comm_r -text "Read"
	ttk::entry $p.lf_comm.fr1.en_comm_r -textvariable ::temp(comm_r)
	ttk::frame $p.lf_comm.fr2 ;#-relief groove
	ttk::label $p.lf_comm.fr2.lb_comm_w -text "Write"
	ttk::entry $p.lf_comm.fr2.en_comm_w -textvariable ::temp(comm_w)

	ttk::labelframe $p.lf_gen -text "General"
	ttk::frame $p.lf_gen.fr1 ;#-relief groove
	ttk::label $p.lf_gen.fr1.lb_timeout -text "Timeout (-t)"
	ttk::entry $p.lf_gen.fr1.en_timeout -textvariable ::temp(timeout)
	ttk::frame $p.lf_gen.fr2 ;#-relief groove
	ttk::label $p.lf_gen.fr2.lb_retry -text "RETRIES (-r)"
	ttk::entry $p.lf_gen.fr2.en_retry -textvariable ::temp(retry)
	ttk::frame $p.lf_gen.fr3 ;#-relief groove
	ttk::label $p.lf_gen.fr3.lb_bind -text "Bind (-B)"
	ttk::combobox $p.lf_gen.fr3.en_bind -textvariable ::snmp::multihomeip -values $::snmp::homeiplist -state normal

	ttk::labelframe  $p.lf_gen.fr4 -text "Output format (-O)"
	ttk::radiobutton $p.lf_gen.fr4.rb1 -value 1 -variable ::temp(output) -style  My.TRadiobutton -text "-O0s    sysUpTimeInstance = Timeticks: (43664654) 5 days, 1:17:26.54"
	ttk::radiobutton $p.lf_gen.fr4.rb2 -value 2 -variable ::temp(output) -style  My.TRadiobutton -text "-O0n    .1.3.6.1.2.1.1.3.0 = Timeticks: (43680332) 5 days, 1:17:26.54"
	ttk::radiobutton $p.lf_gen.fr4.rb3 -value 3 -variable ::temp(output) -style  My.TRadiobutton -text "-O0Qs   sysUpTimeInstance = 5:1:17:26.54"
	ttk::radiobutton $p.lf_gen.fr4.rb4 -value 4 -variable ::temp(output) -style  My.TRadiobutton -text "User defined"
	ttk::entry       $p.lf_gen.fr4.en  -textvariable ::temp(useroutput)
	
	ttk::frame  $p.lf_end
	ttk::button $p.lf_end.bt_ok     -text OK -command {
		foreach varname {ver comm_r comm_w timeout retry output useroutput} {
			set ::snmp::$varname  $::temp($varname)
		}
		if {[info exists ::snmp::multihomeip]} {
			lappend ::snmp::homeiplist $::snmp::multihomeip
			set ::snmp::homeiplist [lsort -unique $::snmp::homeiplist]
		}
		destroy .protocol
	}
	ttk::button $p.lf_end.bt_cancel -text Cancel -command {destroy .protocol}
	
	grid $p.lf_ver -row 0 -column 0  -sticky news -padx 2 -pady 0
	grid $p.lf_ver.rb_v1 -row 0 -column 0 -sticky w -padx 2 -pady 2
	grid $p.lf_ver.rb_v2 -row 0 -column 1 -sticky w -padx 2 -pady 2
	grid $p.lf_ver.rb_v3 -row 0 -column 2 -sticky w -padx 2 -pady 2
	
	grid $p.lf_comm -row 1 -column 0  -sticky news -padx 2 -pady 0 -ipady 2
	grid $p.lf_comm.fr1 -row 0 -column 0 -sticky we -padx 2 -pady 0
	grid $p.lf_comm.fr1.lb_comm_r -row 0 -column 0 -sticky w -padx 2 -pady 1
	grid $p.lf_comm.fr1.en_comm_r -row 0 -column 1 -sticky we -padx 2 -pady 0
	grid $p.lf_comm.fr2 -row 0 -column 1 -sticky we -padx 2 -pady 0
	grid $p.lf_comm.fr2.lb_comm_w -row 0 -column 0 -sticky w -padx 2 -pady 1
	grid $p.lf_comm.fr2.en_comm_w -row 0 -column 1 -sticky we -padx 2 -pady 0 
	
	grid $p.lf_gen -row 2 -column 0  -sticky news -padx 2 -ipady 2
	grid $p.lf_gen.fr1 -row 0 -column 0 -sticky we -padx 2 -pady 2
	grid $p.lf_gen.fr1.lb_timeout -row 0 -column 0 -sticky w -padx 2 -pady 0
	grid $p.lf_gen.fr1.en_timeout -row 0 -column 1 -sticky we -padx 2 -pady 0
	grid $p.lf_gen.fr2 -row 0 -column 1 -sticky we -padx 2 -pady 2
	grid $p.lf_gen.fr2.lb_retry -row 0 -column 0 -sticky w -padx 2 -pady 0
	grid $p.lf_gen.fr2.en_retry -row 0 -column 1 -sticky we -padx 2 -pady 0
	grid $p.lf_gen.fr3 -row 1 -column 0 -columnspan 2 -sticky we -padx 2 -pady 2
	grid $p.lf_gen.fr3.lb_bind -row 0 -column 0 -sticky w -padx 2 -pady 2
	grid $p.lf_gen.fr3.en_bind -row 0 -column 1 -sticky we -padx 2 -pady 2 -ipadx 0	
	grid $p.lf_gen.fr4 -row 2 -column 0 -columnspan 2 -sticky we -padx 2 -pady 0
	grid $p.lf_gen.fr4.rb1 -row 0 -column 0 -columnspan 2 -sticky w -padx 2 -pady 0
	grid $p.lf_gen.fr4.rb2 -row 1 -column 0 -columnspan 2 -sticky w -padx 2 -pady 0
	grid $p.lf_gen.fr4.rb3 -row 2 -column 0 -columnspan 2 -sticky w -padx 2 -pady 0
	grid $p.lf_gen.fr4.rb4 -row 3 -column 0 -sticky w -padx 2 -pady 0
	grid $p.lf_gen.fr4.en  -row 3 -column 1 -sticky we -padx 2 -pady 0
	
	grid $p.lf_end -row 3 -column 0 -sticky we -padx 2 -ipady 0
	grid $p.lf_end.bt_ok -row 0 -column 0      -pady 5
	grid $p.lf_end.bt_cancel -row 0 -column 1  -pady 5 
	
	grid columnconfigure $p.lf_ver 0 -weight 1
	grid columnconfigure $p.lf_ver 1 -weight 1
	grid columnconfigure $p.lf_ver 2 -weight 1
	
	grid columnconfigure $p.lf_comm 0 -weight 1
	grid columnconfigure $p.lf_comm 1 -weight 1
	grid columnconfigure $p.lf_comm.fr1 1 -weight 1
	grid columnconfigure $p.lf_comm.fr2 1 -weight 1

	grid columnconfigure $p.lf_gen 0 -weight 1
	grid columnconfigure $p.lf_gen 1 -weight 1
	grid columnconfigure $p.lf_gen.fr1 1 -weight 1
	grid columnconfigure $p.lf_gen.fr2 1 -weight 1
	grid columnconfigure $p.lf_gen.fr3 1 -weight 1
	
	grid columnconfigure $p.lf_gen.fr4 1 -weight 1
	
	grid columnconfigure $p.lf_end 0 -weight 1
	grid columnconfigure $p.lf_end 1 -weight 1
	

	::tk::PlaceWindow $p 
	grab $p
}



proc snmpv3_setup {} {
	global confPath
	array unset ::tempv3
	foreach varname {usm level authtype authkeytype authkey authpw authkey\
	                           privtype privkeytype privkey privpw privkey \
	                           useDH DHKey} {
		set ::tempv3($varname) [set ::snmp::$varname]
	}
	set ::snmp::DHInit 0
	catch {destroy .protocol.snmpv3}
	set p [toplevel .protocol.snmpv3]
	bind $p <Escape> {destroy .protocol.snmpv3}
	wm resizable $p 0 0 

	wm title $p "snmpv3 Setting"
	wm transient $p [winfo toplevel [winfo parent $p]]

	ttk::labelframe $p.lf_gen -text "General"
	ttk::label $p.lf_gen.lb_usm -text "USER-NAME (-u)"
	ttk::entry $p.lf_gen.en_usm -textvariable ::tempv3(usm)
	ttk::label $p.lf_gen.lb_lv  -text "LEVEL (-l)"
	ttk::radiobutton $p.lf_gen.rb_lv1 -variable ::tempv3(level) -value noAuthNoPriv -text "noAuthNoPriv" 
	ttk::radiobutton $p.lf_gen.rb_lv2 -variable ::tempv3(level) -value authNoPriv   -text "authNoPriv"
	ttk::radiobutton $p.lf_gen.rb_lv3 -variable ::tempv3(level) -value authPriv     -text "authPriv"
	
	ttk::labelframe $p.lf_auth -text "Authentication"
	ttk::label $p.lf_auth.lb_p -text "PROTOCOL (-a)"
	ttk::radiobutton $p.lf_auth.rb1 -variable ::tempv3(authtype)    -value md5 -text "MD5" 
	ttk::radiobutton $p.lf_auth.rb2 -variable ::tempv3(authtype)    -value sha -text "SHA"
	ttk::radiobutton $p.lf_auth.pw  -variable ::tempv3(authkeytype) -value pw  -text "PASSPHRASE (-A)"
	ttk::entry $p.lf_auth.enpw -textvariable  ::tempv3(authpw)
	ttk::radiobutton $p.lf_auth.key -variable ::tempv3(authkeytype) -value key -text "AuthLocalizedKey (-3k)"
	ttk::entry $p.lf_auth.enkey -width 40 -textvariable ::tempv3(authkey)
	
	ttk::labelframe $p.lf_priv -text "Privacy"
	ttk::label $p.lf_priv.lb_p -text "PROTOCOL (-x)"
	ttk::radiobutton $p.lf_priv.rb1 -variable ::tempv3(privtype)    -value des -text "DES" 
	ttk::radiobutton $p.lf_priv.rb2 -variable ::tempv3(privtype)    -value aes -text "AES"
	ttk::radiobutton $p.lf_priv.pw  -variable ::tempv3(privkeytype) -value pw -text "PASSPHRASE (-X)"
	ttk::entry $p.lf_priv.enpw -textvariable  ::tempv3(privpw)
	ttk::radiobutton $p.lf_priv.key -variable ::tempv3(privkeytype) -value key -text "PrivLocalizedKey (-3K)"
	ttk::entry $p.lf_priv.enkey -width 40 -textvariable ::tempv3(privkey)
	
	ttk::labelframe $p.lf_dh -text "Diffie Hellman"
	ttk::checkbutton $p.lf_dh.cb -text "Use Diffie-Hellman" -variable ::tempv3(useDH)
	ttk::label $p.lf_dh.lb -text "Private key" 
	ttk::entry $p.lf_dh.en -textvariable ::tempv3(DHKey)
	
	ttk::frame  $p.lf_end
	ttk::button $p.lf_end.bt_load -text "Load profile" -command {		
		set profile [tk_getOpenFile -initialdir $confPath/profile]
		if {$profile != ""} {
			foreach name [array names ::tempv3] {set ::tempv3($name) ""}
			set inifd [::ini::open $profile r]
			catch {
			foreach key [::ini::keys $inifd snmpv3] {
				set ::tempv3($key) [ ::ini::value $inifd snmpv3 $key]
			}}
			::ini::close $inifd

		}
	}
	ttk::button $p.lf_end.bt_save -text "Save profile" -command {
		set profile [tk_getSaveFile -initialdir $confPath/profile]
		if {$profile != ""} {
			set inifd [::ini::open $profile w+]
			foreach name [array names ::tempv3] {
				::ini::set $inifd snmpv3 $name $::tempv3($name)
			}
			::ini::commit $inifd
			::ini::close $inifd
		}
		
	}
	ttk::button $p.lf_end.bt_ok     -text OK -command {
		foreach varname [array names ::tempv3] {
			set ::snmp::$varname  $::tempv3($varname)
		}
		destroy .protocol.snmpv3
	}
	ttk::button $p.lf_end.bt_cancel -text Cancel -command {destroy .protocol.snmpv3}
	
	
	grid $p.lf_gen -row 0 -column 0 -sticky we
	grid $p.lf_gen.lb_usm -row 0 -column 0 -padx 2 -pady 2 -sticky w
	grid $p.lf_gen.en_usm -row 0 -column 1 -padx 2 -pady 2 -sticky we -columnspan 3
	grid $p.lf_gen.lb_lv  -row 1 -column 0 -padx 2 -pady 2 -sticky w
	grid $p.lf_gen.rb_lv1 -row 1 -column 1 -padx 2 -pady 2 -sticky w
	grid $p.lf_gen.rb_lv2 -row 1 -column 2 -padx 2 -pady 2 -sticky w
	grid $p.lf_gen.rb_lv3 -row 1 -column 3 -padx 2 -pady 2 -sticky w
	
	grid $p.lf_auth -row 1 -column 0 -sticky we
	grid $p.lf_auth.lb_p -row 0 -column 0 -padx 2 -pady 2 -sticky w  
	grid $p.lf_auth.rb1  -row 0 -column 1 -padx 2 -pady 2 -sticky w
	grid $p.lf_auth.rb2  -row 0 -column 2 -padx 2 -pady 2 -sticky w	
	grid $p.lf_auth.pw    -row 1 -column 0 -padx 2 -pady 2 -sticky w
	grid $p.lf_auth.enpw  -row 1 -column 1 -padx 2 -pady 2 -sticky we -columnspan 2
	grid $p.lf_auth.key   -row 2 -column 0 -padx 2 -pady 2 -sticky w
	grid $p.lf_auth.enkey -row 2 -column 1 -padx 2 -pady 2 -sticky we -columnspan 2
	
	grid $p.lf_priv -row 2 -column 0 -sticky we
	grid $p.lf_priv.lb_p -row 0 -column 0 -padx 2 -pady 2 -sticky w  
	grid $p.lf_priv.rb1  -row 0 -column 1 -padx 2 -pady 2 -sticky w
	grid $p.lf_priv.rb2  -row 0 -column 2 -padx 2 -pady 2 -sticky w	
	grid $p.lf_priv.pw    -row 1 -column 0 -padx 2 -pady 2 -sticky w
	grid $p.lf_priv.enpw  -row 1 -column 1 -padx 2 -pady 2 -sticky we -columnspan 2
	grid $p.lf_priv.key   -row 2 -column 0 -padx 2 -pady 2 -sticky w
	grid $p.lf_priv.enkey -row 2 -column 1 -padx 2 -pady 2 -sticky we -columnspan 2
	
	grid $p.lf_dh -row 3 -column 0 -sticky we
	grid $p.lf_dh.cb -row 0 -column 0 -padx 2 -pady 2 -sticky w
	grid $p.lf_dh.lb -row 1 -column 0 -padx 2 -pady 2 -sticky w
	grid $p.lf_dh.en -row 2 -column 0 -padx 2 -pady 2 -sticky we -columnspan 2
	
	grid $p.lf_end -row 4 -column 0 -sticky we
	grid $p.lf_end.bt_load   -row 0 -column 0 -pady 5
	grid $p.lf_end.bt_save   -row 0 -column 1 -pady 5
	grid $p.lf_end.bt_ok     -row 0 -column 2 -pady 5
	grid $p.lf_end.bt_cancel -row 0 -column 3 -pady 5 	
	
	grid columnconfigure $p.lf_gen 0 -weight 1
	grid columnconfigure $p.lf_gen 1 -weight 1
	grid columnconfigure $p.lf_gen 2 -weight 1
	grid columnconfigure $p.lf_gen 3 -weight 1	
	grid columnconfigure $p.lf_auth 0 -weight 1
	grid columnconfigure $p.lf_auth 1 -weight 1
	grid columnconfigure $p.lf_auth 2 -weight 1
	grid columnconfigure $p.lf_priv 0 -weight 1
	grid columnconfigure $p.lf_priv 1 -weight 1
	grid columnconfigure $p.lf_priv 2 -weight 1
	grid columnconfigure $p.lf_dh 0 -weight 1
	grid columnconfigure $p.lf_dh 1 -weight 1
	grid columnconfigure $p.lf_end 0 -weight 1
	grid columnconfigure $p.lf_end 1 -weight 1
	grid columnconfigure $p.lf_end 2 -weight 1
	grid columnconfigure $p.lf_end 3 -weight 1
	::tk::PlaceWindow $p
	grab $p
}

proc mib_setup {} {
	global TREE
	catch {destroy .mib_setup}
	array unset ::temp
	foreach varname {MIBDIRS TREE_DSP_TYPE} {
		set ::temp($varname) [set ::snmp::$varname]
	}
	set ::temp(changedir) 0
	set p [toplevel .mib_setup]
	bind $p <Escape> {destroy .mib_setup}
	wm resizable $p 0 0 

	wm title $p "MIB Setting"
	wm transient $p [winfo toplevel [winfo parent $p]]

	ttk::labelframe   $p.lf1 -text "MIB DIR"
	ttk::label        $p.lf1.lb_dir -text "DIR"
	ttk::entry        $p.lf1.en_dir -textvariable ::temp(MIBDIRS)
	ttk::button       $p.lf1.bt_dir -text "set..." -command {
		set newdir [tk_chooseDirectory -mustexist 1 -initialdir $::temp(MIBDIRS) -parent .mib_setup -title "Select MIB dir and re-build mib tree"]
		if {$newdir!=""} {
			if {$::temp(MIBDIRS) != $newdir} {
				set ::temp(MIBDIRS) $newdir
				set ::temp(changedir) 1
			}
		}
	}
	ttk::labelframe   $p.lf2 -text "MIB tree dispaly"
	ttk::radiobutton  $p.lf2.r1 -value 1 -variable ::temp(TREE_DSP_TYPE) -style  My.TRadiobutton -text "mib_name              : sysDescr"
	ttk::radiobutton  $p.lf2.r2 -value 2 -variable ::temp(TREE_DSP_TYPE) -style  My.TRadiobutton -text "mib_name (short oid)  : sysDescr (1)"
	ttk::radiobutton  $p.lf2.r3 -value 3 -variable ::temp(TREE_DSP_TYPE) -style  My.TRadiobutton -text "mib_name (full oid)   : sysDescr (1.3.6.1.4.1.1.1)"
	
	ttk::frame  $p.lf_end
	ttk::button $p.lf_end.bt_ok     -text OK -command {
		foreach varname [array names ::temp] {
			set ::snmp::$varname  $::temp($varname)
		}
		change_tree_dsp
		if {$::temp(changedir)} {
			save_bookmark
			set ::snmp::bookmark_list ""
			array unset ::BOOKMARK
			catch {$TREE item delete 1}
			unset ::snmp::namelist			
			snmp_loadmib -mall -M$newdir
			snmp_translate -TZ -f[file join $confPath translate_output.txt]
			catch {buildtree}
		}
		
		destroy .mib_setup
	}
	ttk::button $p.lf_end.bt_cancel -text Cancel -command {destroy .mib_setup}
				
	grid $p.lf1.lb_dir -sticky w  -row 0 -column 0 -padx 5
	grid $p.lf1.en_dir -sticky we -row 0 -column 1 -padx 5
	grid $p.lf1.bt_dir -sticky we -row 0 -column 2 -padx 5
	grid $p.lf2.r1 -sticky w 
	grid $p.lf2.r2 -sticky w
	grid $p.lf2.r3 -sticky w
	grid $p.lf1 -row 0 -column 0 -sticky we
	grid $p.lf2 -row 1 -column 0 -sticky we
	grid $p.lf_end -row 2 -column 0 -sticky we
	grid $p.lf_end.bt_ok -row 0 -column 0     -pady 5
	grid $p.lf_end.bt_cancel -row 0 -column 1 -pady 5 	
	grid columnconfigure $p 0 -weight 1
	grid columnconfigure $p.lf1 1 -weight 1
	grid columnconfigure $p.lf_end 0 -weight 1
	grid columnconfigure $p.lf_end 1 -weight 1
	::tk::PlaceWindow $p 
	grab $p
}


proc font_setup {} {
	global TREE MIBINFO RESULT
	catch {destroy .font_setup}
	set p [toplevel .font_setup]
	bind $p <Escape> {destroy .font_setup}
	wm resizable $p 0 0

	wm title $p "Font Setting"
	wm transient $p [winfo toplevel [winfo parent $p]]	
	tk fontchooser configure -parent .font_setup
	
	ttk::frame  .font_setup.fr
	
	ttk::label  .font_setup.fr.lb_tree      -text "MIB Tree:"
	ttk::label  .font_setup.fr.lb_tree_font -text "$::tree_font" -font $::tree_font
	ttk::button .font_setup.fr.bt_tree_set  -text "Set" -command {		
		tk fontchoose configure -font [lindex [$TREE element cget elemText -font] 0] -command [list set_tree_font .font_setup.fr.lb_tree_font ::tree_font]
		tk fontchooser show
	}

	ttk::label  .font_setup.fr.lb_info      -text "MIB info:"
	ttk::label  .font_setup.fr.lb_info_font -text "$::info_font" -font $::info_font
	ttk::button .font_setup.fr.bt_info_set  -text "Set" -command {		
		tk fontchoose configure -font [$MIBINFO cget -font] -command [list set_font $MIBINFO .font_setup.fr.lb_info_font ::info_font]
		tk fontchooser show
	}

	ttk::label  .font_setup.fr.lb_ret      -text "Result:"
	ttk::label  .font_setup.fr.lb_ret_font -text "$::result_font" -font $::result_font
	ttk::button .font_setup.fr.bt_ret_set  -text "Set" -command {		
		tk fontchoose configure -font [$RESULT cget -font] -command [list set_font $RESULT .font_setup.fr.lb_ret_font ::result_font]
		tk fontchooser show
	}
	
	grid .font_setup.fr
	grid .font_setup.fr.lb_tree      -row 0 -column 0 -ipadx 2 -ipady 2 -sticky w
	grid .font_setup.fr.lb_tree_font -row 0 -column 1 -ipadx 4 -ipady 2 -sticky we
	grid .font_setup.fr.bt_tree_set  -row 0 -column 2 -ipadx 2 -ipady 2
	grid .font_setup.fr.lb_info      -row 1 -column 0 -ipadx 2 -ipady 2 -sticky w
	grid .font_setup.fr.lb_info_font -row 1 -column 1 -ipadx 4 -ipady 2 -sticky we
	grid .font_setup.fr.bt_info_set  -row 1 -column 2 -ipadx 2 -ipady 2
	grid .font_setup.fr.lb_ret       -row 2 -column 0 -ipadx 2 -ipady 2 -sticky w
	grid .font_setup.fr.lb_ret_font  -row 2 -column 1 -ipadx 4 -ipady 2 -sticky we
	grid .font_setup.fr.bt_ret_set   -row 2 -column 2 -ipadx 2 -ipady 2

	::tk::PlaceWindow $p 

}

	
proc set_font { w1 w2 var font args} {
	upvar $var var_ptr
	$w1 configure -font [font actual $font]
	set var_ptr "\"[font actual $font -family]\" [font actual $font -size] [font actual $font -weight]"
	$w2 configure -text "[font actual $font -family] [font actual $font -size] [font actual $font -weight]" -font $var_ptr
}

proc set_tree_font {w var font args} {
	global TREE	
	upvar $var var_ptr
	$TREE element configure elemText  -font [list [font actual $font] {} ]
	$TREE element configure elemText2 -font [list [font actual $font] {} ]
	$TREE element configure elemText3 -font [list [font actual $font] {} ]	
	set var_ptr "\"[font actual $font -family]\" [font actual $font -size] [font actual $font -weight]"
	$w configure -text "[font actual $font -family] [font actual $font -size] [font actual $font -weight]" -font $var_ptr
}

proc change_tree_dsp {} {
	global TREE
	switch $::snmp::TREE_DSP_TYPE {
		"1" {
			$TREE style layout style1 elemRect -union {elemText}
			$TREE style layout style1 elemText2 -visible 0
			$TREE style layout style1 elemText3 -visible 0
		}
		"2" {
			$TREE style layout style1 elemRect -union {elemText elemText2} 
			$TREE style layout style1 elemText2 -visible 1
			$TREE style layout style1 elemText3 -visible 0
		}
		"3" {
			$TREE style layout style1 elemRect -union {elemText elemText3}
			$TREE style layout style1 elemText2 -visible 0
			$TREE style layout style1 elemText3 -visible 1
		}
	}	
}


proc snmpget_gui {{method get}} {
	global RESULT

	foreach {ret index_list} [get_index] {}
	if {!$ret} {
		if {$::result_clear} {$RESULT delete 1.0 end}
		log_result "Error: get index fail\n" err
		log_result "[string trim $index_list]\n" err
		return
	}

	if { [llength $index_list] == 1} {
		set oid [set ::snmp::OID].[string trim [lindex $index_list 0]]
		run_cmd "snmp_$method [::snmp::cmdopt] [::snmp::bind] [::snmp::outfmt] [::snmp::addr] $oid"
		return

	}
	
	if {[llength $index_list]==0} {
		return
	}
	catch {destroy .snmpget}
	set p [toplevel .snmpget]
	bind $p <Escape> {destroy .snmpget}
	wm title $p "Select index"
	wm resizable $p 0 0 
	wm transient $p [winfo toplevel [winfo parent $p]]
	ttk::combobox .snmpget.cb -value $index_list -state readonly

	set ::temp_method $method
	ttk::button .snmpget.bt -text "$method" -command {
		run_cmd "snmp_[set ::temp_method] [::snmp::cmdopt] [::snmp::bind] [::snmp::outfmt] [::snmp::addr] $::snmp::OID.[.snmpget.cb get]"
		unset ::temp_method
		destroy .snmpget
	}
	
	.snmpget.cb current 0	
	grid .snmpget.cb -row 0 -column 0 -sticky we -padx 5 -pady 5
	grid .snmpget.bt -row 1 -column 0 -sticky we -padx 5 -pady 5
	focus .snmpget.cb
	::tk::PlaceWindow $p 
	grab $p
}

proc snmptable_gui {{method get}} {
	global RESULT

	#foreach {ret index_list} [get_index] {}
	#if {!$ret} {
	#	if {$::result_clear} {$RESULT delete 1.0 end}
	#	log_result "Error: get index fail\n" err
	#	log_result "[string trim $index_list]\n" err
	#	return
	#}

	#if { [llength $index_list] == 1} {
	#	set oid [set ::snmp::OID].[string trim [lindex $index_list 0]]
	#	run_cmd "snmp_$method [::snmp::cmdopt] [::snmp::outfmt] [::snmp::addr] $oid"
	#	return

	#}
	#
	#if {[llength $index_list]==0} {
	#	return
	#}
	catch {destroy .snmptable}
	set p [toplevel .snmptable]
	bind $p <Escape> {destroy .snmptable}
	wm title $p "Select index"
	wm resizable $p 1 1 
	wm transient $p [winfo toplevel [winfo parent $p]]
	set tbl $p.tbl
	scrollbar $p.hsb -orient horizontal -command [list $tbl xview]
	scrollbar $p.vsb -orient vertical -command [list $tbl yview]
	tablelist::tablelist $tbl \
	-xscrollcommand [list .snmptable.hsb set] \
	-yscrollcommand [list .snmptable.vsb set] \
	-showseparators 1 -font {Arial 12 {}} \
	-columns "0 oid 0 value"
	# \
	#-labelcommand  tablelist::sortByColumn \
	#-showseparators 0	
	
	grid $tbl -row 0 -column 0 -sticky news
	grid .snmptable.vsb -row 0 -column 1 -sticky ns
	grid .snmptable.hsb -row 1 -column 0 -sticky we
	grid columnconfigure .snmptable 0 -weight 1
	grid rowconfigure .snmptable 0 -weight 1
	
	#.snmptable.tbl insert end [list "111" "222"]
	
	#ttk::combobox .snmpget.cb -value $index_list -state readonly

	#set ::temp_method $method
	#ttk::button .snmpget.bt -text "$method" -command {
	#	run_cmd "snmp_[set ::temp_method] [::snmp::cmdopt] [::snmp::outfmt] [::snmp::addr] $::snmp::OID.[.snmpget.cb get]"
	#	unset ::temp_method
	#	destroy .snmpget
	#}
	#
	#.snmpget.cb current 0	
	#grid .snmpget.cb -row 0 -column 0 -sticky we -padx 5 -pady 5
	#grid .snmpget.bt -row 1 -column 0 -sticky we -padx 5 -pady 5
	#focus .snmpget.cb
	::tk::PlaceWindow $p 
	grab $p
}

proc get_index {} {
	if [catch {eval snmp_walk [::snmp::cmdopt] -OQnb [::snmp::addr]  $::snmp::OID} ret] {
		return [list 0 $ret]
	} else {
		set index_list ""
		foreach vbind $ret {
			set retoid [string trim [lindex [split $vbind =] 0]]
			if [regexp "[set ::snmp::OID]\.(.+)" [string trimleft $retoid .] match index] {
				lappend index_list $index
			}
		}
		return [list 1	$index_list]
	}
}



proc snmp_dump {args} {
	global RESULT confPath
	set oid [lindex $args end]
	if [catch {eval snmp_get [::snmp::cmdopt] -Oqvx -IJ  [::snmp::addr]  $oid } ret] {
		log_result "Err: $ret \n" err
	} else {
		set hexdata [join [split [lindex $ret 0] " \n\""] ""]
		set dumpfile [tk_getSaveFile -initialdir $confPath/dumpfile]
		if {$dumpfile!=""} {
			set fd [open $dumpfile w] 
			fconfigure $fd -translation binary			
			puts -nonewline $fd [binary format H* $hexdata]
			close $fd
		}
		log_result "Dump data to $dumpfile\n"		
	}
}


proc snmp_upload {args} {
	global RESULT confPath	
	set oid [lindex $args end]
	if {![info exist ::snmp::initdir]} {
		set ::snmp::initdir [file join $confPath dumpfile]
	}	
	set loadfd [tk_getOpenFile -initialdir $::snmp::initdir]
	if {$loadfd==""} {return}
	set ::snmp::initdir	[file dirname $loadfd]
	set fd [open $loadfd r]
	fconfigure $fd -translation binary
	binary scan [read $fd] H* hexdata
	
	if [catch {eval snmp_set [::snmp::cmdopt rw] [::snmp::outfmt] [::snmp::addr]  $oid x $hexdata} ret] {
		log_result "Error: $ret \n"	err
	} else {
		log_result "Upload $loadfd\n"		
	}
}


proc snmpset_gui {} {	
	global RESULT
	
	set ::backupOID $::snmp::OID
    foreach {ret index_list} [get_index] {}

	set oid_list ""
	if {!$ret} {
    	if {$::result_clear} {$RESULT delete 1.0 end}
		log_result "Error: get index fail\n" err
		log_result "[string trim $index_list]\n" err
		return
    } else {
    	foreach ind $index_list {
    		lappend oid_list "[set ::snmp::OID].$ind"
    	}
    }
	if {$oid_list==""} {
		lappend oid_list "[set ::snmp::OID].0"
	}
	catch {destroy .snmpset}
	set w [toplevel .snmpset]
	bind $w <Escape> {set ::snmp::OID $::backupOID ; destroy .snmpset}
	
	wm title $w "Snmpset"
	wm resizable $w 0 0 
	wm transient $w [winfo toplevel [winfo parent $w]]	
	wm protocol $w WM_DELETE_WINDOW {set ::snmp::OID $::backupOID ; destroy .snmpset}
	ttk::labelframe $w.lf1 -text "Remote SNMP agent"
	ttk::entry $w.lf1.en -textvariable ::snmp::agentip
	ttk::button $w.lf1.bt_conf -text "SNMP Setting" -command snmp_protocol
#	ttk::button $w.lf1.bt2_conf
	
	ttk::labelframe $w.lf2 -text "OID to Set"
	
	ttk::combobox $w.lf2.cb -textvariable ::snmp::OID -values $oid_list
#	ttk::button $w.lf2.bt_conf
	.snmpset.lf2.cb curren 0
	ttk::labelframe $w.lf3 -text "Value to Set"
	ttk::entry $w.lf3.en -textvariable ::snmp::setvalue
	set ::snmp::setvalue ""
	ttk::button $w.lf3.bt_conf -text "Get" -command {
		set oid [.snmpset.lf2.cb get]
		set ::snmp::setvalue [lindex [eval snmp_get [::snmp::cmdopt]  -OqvU -IJ [::snmp::addr]  $oid] 0]
	}
	ttk::button $w.lf3.bt2_conf -text "Set" -command {
		set oid [.snmpset.lf2.cb get]	
		run_cmd "snmp_set [::snmp::cmdopt rw] [::snmp::bind] [::snmp::outfmt] [::snmp::addr] $oid $::snmp::TYPE $::snmp::setvalue"
		set ::snmp::OID $::backupOID
		destroy .snmpset
	}
	
	ttk::separator $w.sep -orient horizontal  
	
	ttk::labelframe $w.lf4 -text "Syntax"
	ttk::radiobutton $w.lf4.rb1 -text "INTEGER" -variable ::snmp::TYPE -value i
	ttk::radiobutton $w.lf4.rb2 -text "UINTEGER" -variable ::snmp::TYPE -value u
	ttk::radiobutton $w.lf4.rb3 -text "TIMETICKS" -variable ::snmp::TYPE -value t
	ttk::radiobutton $w.lf4.rb4 -text "IPADDRESS" -variable ::snmp::TYPE -value a
	ttk::radiobutton $w.lf4.rb5 -text "OBJID" -variable ::snmp::TYPE -value o
	ttk::radiobutton $w.lf4.rb6 -text "STRING" -variable ::snmp::TYPE -value s
	ttk::radiobutton $w.lf4.rb7 -text "HEX STRING" -variable ::snmp::TYPE -value x
	ttk::radiobutton $w.lf4.rb8 -text "DEC STRING" -variable ::snmp::TYPE -value d
	ttk::radiobutton $w.lf4.rb9 -text "BITS" -variable ::snmp::TYPE -value b
	# ttk::radiobutton $w.lf4.rb3 -text "INTEGER64" -variable snmp_TYPE -value I
	# ttk::radiobutton $w.lf4.rb3 -text "UINTEGER64" -variable snmp_TYPE -value U
	# ttk::radiobutton $w.lf4.rb3 -text "float" -variable snmp_TYPE -value F
	# ttk::radiobutton $w.lf4.rb3 -text "double" -variable snmp_TYPE -value D

	# TYPE: one of i, u, t, a, o, s, x, d, b
	# i: INTEGER, u: unsigned INTEGER, t: TIMETICKS, a: IPADDRESS
	# o: OBJID, s: STRING, x: HEX STRING, d: DECIMAL STRING, b: BITS
	# U: unsigned int64, I: signed int64, F: float, D: double
	   
	grid $w.lf1 -sticky we -padx 5
	grid $w.lf1.en      -row 0 -column 0 -padx 2 -sticky we
	grid $w.lf1.bt_conf -row 0 -column 1 -padx 2 -sticky w
#$w.lf1.bt_conf $w.lf1.bt2_conf -sticky we -padx 5
	grid columnconfig $w.lf1 0 -weight 1
	
	
	grid $w.lf2 -sticky we -padx 5
	grid $w.lf2.cb  -sticky we -padx 5
#	$w.lf2.bt_conf
	grid columnconfig $w.lf2 0 -weight 1
	
	grid $w.lf3 -sticky we -padx 5
	grid $w.lf3.en $w.lf3.bt_conf $w.lf3.bt2_conf -sticky we -padx 5
	grid columnconfig $w.lf3 0 -weight 1
	grid $w.sep -sticky we
	
	grid $w.lf4 -sticky we -padx 5
	grid $w.lf4.rb1 $w.lf4.rb2 $w.lf4.rb3 -sticky w -padx 5 -pady 5
	grid $w.lf4.rb4 $w.lf4.rb5 $w.lf4.rb6 -sticky w -padx 5 -pady 5
	grid $w.lf4.rb7 $w.lf4.rb8 $w.lf4.rb9 -sticky w -padx 5 -pady 5	
	::tk::PlaceWindow $w
	
	bind .snmpset.lf3.en <Return> {
		.snmpset.lf3.bt2_conf invoke
	}
	grab $w
	focus $w.lf3.en
}



proc ::snmp::snmpdump {} {
	global RESULT
	if {$::snmp::OID==""} {return}
	$RESULT tag remove match 1.0 end
	$RESULT tag remove mark  1.0 end
	snmpget_gui dump
}

proc ::snmp::snmpupload {} {
	global RESULT	
	if {$::snmp::OID==""} {return}	
	$RESULT tag remove match 1.0 end
	$RESULT tag remove mark  1.0 end
	snmpget_gui upload
}


proc snmpwalk {args} {
	puts $args
	set option [lrange $args 0 end-1] 
	set oid [lindex $args end]
	set addr [lindex $args end-1]
	#puts [eval snmp_getnext $option $oid]
	#set nextoid [string trim [lindex [split [lindex [eval snmp_getnext [::snmp::cmdopt] -OQn [::snmp::addr]  $::snmp::OID] 0] =] 0] .]
	#puts nextoid=$nextoid
	#if oid_ischild  $::snmp::OID nextoid

	while {1} {
		set nextoid [string trim [lindex [split [lindex [eval snmp_getnext [::snmp::cmdopt] [::snmp::bind] -OQn [::snmp::addr]  $oid] 0] =] 0] .]
		#puts oid=$oid
		#puts nextoid=$nextoid
		if {![oid_ischild [lindex $args end] $nextoid]} {break}
		log_result [lindex [eval snmp_getnext $option  $oid] 0]\n
		update
		set oid $nextoid
	}
}

proc oid_ischild {oid1 oid2} {
	set stra $oid1.
	puts $stra
	set leng [string length $stra]
	set strb [string range $oid2 0 [expr $leng-1]]
	if {[string eq $stra $strb]} {
		return 1
	}
	return 0
}

proc ::snmp::snmpwalk {} {
	if {$::snmp::OID==""} {return}
	run_cmd "snmp_walk [::snmp::cmdopt] [::snmp::bind] [::snmp::outfmt] [::snmp::addr]  $::snmp::OID"
	#run_cmd "snmpwalk [::snmp::cmdopt] [::snmp::outfmt] [::snmp::addr]  $::snmp::OID"
}

proc ::snmp::snmpbulkget {} {
	if {$::snmp::OID==""} {return}
	run_cmd "snmp_bulkget [::snmp::cmdopt] [::snmp::bind] [::snmp::outfmt] [::snmp::addr]  $::snmp::OID"
	#run_cmd "snmpwalk [::snmp::cmdopt] [::snmp::outfmt] [::snmp::addr]  $::snmp::OID"
}

proc ::snmp::snmptable {} {
	if {$::snmp::OID==""} {return}
	snmptable_gui
	set rets [eval snmp_walk [::snmp::cmdopt] [::snmp::bind] [::snmp::outfmt] [::snmp::addr]  $::snmp::OID]
	foreach ret $rets {
		.snmptable.tbl insert end [list [lindex $ret 0] [lindex $ret 2]]	
	}
	
	while {[winfo exist .snmptable]} {
		Sleep 1000	
		set rets [eval snmp_walk [::snmp::cmdopt] [::snmp::outfmt] [::snmp::addr]  $::snmp::OID]
		set row_ind 0
		foreach ret $rets {
			if {![winfo exist .snmptable]} {break}
			.snmptable.tbl cellconfigure $row_ind,0 -text [lindex $ret 0]
			.snmptable.tbl cellconfigure $row_ind,1 -text [lindex $ret 2]
			incr row_ind
		}
		#.snmptable.tbl insert end [list [lindex $ret 0] [lindex $ret 2]]
		
	}
	
	#.snmptable.tbl insert end [list "111" "222"]
}

proc ::snmp::snmpset {} {
	if {$::snmp::OID==""} {return}
	snmpset_gui
}

proc ::snmp::snmpget {} {
	if {$::snmp::OID==""} {return}
	snmpget_gui
}

proc ::snmp::snmpgetnext {} {
	if {$::snmp::OID==""} {return}
	run_cmd "snmp_getnext [::snmp::cmdopt] [::snmp::bind] [::snmp::outfmt] [::snmp::addr]  $::snmp::OID"
}

proc ::snmp::bind {} {
	if {[info exists ::snmp::multihomeip]} {
		return "-B$::snmp::multihomeip"	
	}
}

proc ::snmp::outfmt {} {
	switch $::snmp::output {
		"1" {return -O0s}
		"2" {return -O0n}
		"3" {return -O0Qs}
		"4" {return $::snmp::useroutput}
	}
}

proc ::snmp::cmdopt {{rw r}} {
	set general_op "-t$::snmp::timeout -r$::snmp::retry -v$::snmp::ver"
	
	if {$::snmp::ver != 3} {
		if {$rw=="r"} {
			set opt "$general_op -c$::snmp::comm_r"
		} else {
			set opt "$general_op -c$::snmp::comm_w"
		}		
		return "$opt"
	}
	set opt "$general_op -u$::snmp::usm"
	if {$::snmp::useDH==""} {set ::snmp::useDH 0}
	if {$::snmp::useDH && !$::snmp::DHInit} {
		log_result "snmpv3 Diffie-Hellman Init\n"		
		set agentkey 0x[get_agent_key [::snmp::addr] $::snmp::usm]
		log_result "Agent key is $agentkey\n"
		set sk [calc_sharekey $agentkey $::snmp::DHKey]
		log_result "Share key is $sk\n"
		
		set auth_salt \x98\xdf\xb5\xac
		set priv_salt \xd1\x31\x0b\xa6
		set sk [binary format H* $sk]
		set ::snmp::DHauth_key [::pbkdf2::pbkdf2 $sk $auth_salt 500 16]
		set ::snmp::DHpriv_key [::pbkdf2::pbkdf2 $sk $priv_salt 500 16]		
		log_result "auth_key=$::snmp::DHauth_key\n"
		log_result "priv_key=$::snmp::DHpriv_key\n\n"
		set ::snmp::DHInit 1	
	}
	
	if {$::::snmp::useDH && $::snmp::DHInit} {
		set opt "$opt -lauthPriv -amd5 -3k$::snmp::DHauth_key -xdes -3K$::snmp::DHpriv_key"
		return $opt
	}
	
	switch $::snmp::level {
		"authNoPriv" {
			if {$::snmp::authkeytype=="pw"} {
				set opt "$opt -l$::snmp::level -a$::snmp::authtype -A$::snmp::authpw"
			} else {
				set opt "$opt -l$::snmp::level -a$::snmp::authtype -3k$::snmp::authkey"
			}
		}
		"authPriv" {
			if {$::snmp::authkeytype=="pw"} {
				set opt "$opt -l$::snmp::level -a$::snmp::authtype -A$::snmp::authpw"
			} else {
				set opt "$opt -l$::snmp::level -a$::snmp::authtype -3k$::snmp::authkey"
			}
			
			if {$::snmp::privkeytype=="pw"} {
				set opt "$opt -x$::snmp::privtype -X$::snmp::privpw"
			} else {
				set opt "$opt -x$::snmp::privtype -3K$::snmp::privkey"
			}
		}
	}
	return "$opt -l$::snmp::level"	
}


proc ::snmp::addr {} {
	if {$::snmp::IPv6} {
		if {[::ip::version $::snmp::agentip] ==6} {
			return udp6:\\\[[string trim $::snmp::agentip]\\\]
		}		
		return udp6:[string trim $::snmp::agentip]
	} else {
		return [string trim $::snmp::agentip]
	}	
}


proc calc_sharekey {remote_public local_random} {
	set prim 0xFFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE65381FFFFFFFFFFFFFFFF
	set ss [bigint::powm $remote_public $local_random $prim]	
	set hex [bigint::hex $ss]
	if [expr [string length $hex] % 2] {
		set hex 0$hex
	}
	return $hex
}

proc get_agent_key {cm_ip usm} {
	if [catch {set ret [ snmp_walk -Oqs -v3 -u dhKickstart -l noAuthNoPriv $cm_ip usmDHKickstartSecurityName]} ret] {
		puts "get usm fail,puts ret=$ret"
		return -1
	}
	foreach line  $ret {
		puts line=$line
		if {[lindex $line 1]==$usm} {
			if [regexp {usmDHKickstartSecurityName\.([\d]+)} [lindex $line 0] match index] {			
				break
			}
		}
	}
	# check index
	set ret [ snmp_get -m all -Oqv -v3 -u dhKickstart -l noAuthNoPriv $cm_ip usmDHKickstartSecurityName.$index]	
	if {![string eq $ret $usm]} {
		puts "get index fail"
		return -1
	}
	
	# get agent key
	set agent_key [lindex [snmp_get -m all -Oqvx -v3 -u dhKickstart -l noAuthNoPriv $cm_ip usmDHKickstartMyPublic.$index] 0]
	# check manager public key
	# ...
	
	return [join [split $agent_key " \"\n"] ""]
}


# highlight all matched result

proc search_result {} {
	global RESULT
	#if {![info exist ::prev_search]} {
	#	set ::prev_search ""
	#}
	# only re-search when patten change
	
	#if {$::prev_search != $::searchresult} {}
	
	$RESULT tag remove match 1.0 end
	$RESULT tag remove mark  1.0 end
	set ::matchlist ""
	#set ::matchmark 1.0
	if { $::res_direction == "down" } {
		set ::matchmark 1.0
	} else {
		set ::matchmark [$RESULT index end]
	}
	set ind 1.0
	set ::prev_search $::searchresult
	if {$::searchresult==""} {			
		return
	}
	while { [set ret [$RESULT search $::searchresult $ind end]] != ""} {
		lappend ::matchlist $ret
		set ind $ret+[string length $::searchresult]chars
		set ret [$RESULT search $::searchresult $ind end]

	}
	foreach match $::matchlist {
		$RESULT tag add match $match $match+[string length $::searchresult]c
	}
	
	if { $::res_direction == "down" } {
		set ::match_mark 0.0
	} else {
		set ::match_mark end
	}		
}



proc mark_next {} {
	global RESULT
	
	if {$::searchresult==""} {return}
	set have_match [$RESULT search $::searchresult 0.0 end]
	set match [$RESULT search $::searchresult $::match_mark+[string length $::searchresult]c end]
	if { $match=="" && ([llength $have_match] > 0) } {set match [lindex $have_match 0]}
	if {$match != ""} {
		$RESULT tag remove mark 1.0 end
		$RESULT tag add mark $match $match+[string length $::searchresult]c
		$RESULT see mark.first
		set ::match_mark $match
	}	
}


proc mark_prev {} {
	global RESULT

	if {$::searchresult==""} {return}
	set have_match [$RESULT search -backwards $::searchresult end 0.0]
	set match [$RESULT search -backwards $::searchresult $::match_mark 0.0]
	if { $match=="" && ([llength $have_match] > 0) } {set match [lindex $have_match 0]}
	if {$match != ""} {
		$RESULT tag remove mark 1.0 end
		$RESULT tag add mark $match $match+[string length $::searchresult]c
		$RESULT see mark.first
		set ::match_mark $match
	}	
}



proc showtime {} {
	return [clock format [clock seconds] -format %y%m%d-%H%M%S]
}

proc save_result {} {
	global RESULT confPath
	set save_path [tk_getSaveFile -initialdir $confPath -initialfile result-[showtime].log]
	if {$save_path != ""} {
		set fd [open $save_path w]
		puts -nonewline $fd [$RESULT get 1.0 end]
		close $fd
	}
}

proc goto_next_bm {} {
	global TREE
	set now [$TREE selection get]
	foreach new $::snmp::bookmark_list {
		if {$new > $now} {
			goto_node $new
			break
		}
	}
}

proc goto_prev_bm {} {
	global TREE
	set now [$TREE selection get]
	set ind 0
	set break 0
	foreach new $::snmp::bookmark_list {
		if { ($new >= $now)} {
			if {!$ind} {set break 1 ;break}
			goto_node [lindex $::snmp::bookmark_list [expr $ind-1]]
			set break 1
			break
		}
		incr ind
	}
	if {$ind && !$break} {
		goto_node [lindex $::snmp::bookmark_list end]
	}
}

proc save_bookmark {} {
	global TREE confPath
	set fd [open [file join $confPath bookmark] w]
	foreach name [array names ::BOOKMARK] {
		if {[regexp {(.+),state} $name match oid]} {
			if {$::BOOKMARK($name)} {
				puts $fd "$oid \t $::BOOKMARK($oid,name)"
			}
		}
	}		
	close $fd
}

proc load_bookmark {} {
	global TREE confPath
	if [file exist [file join $confPath bookmark]] { 
		set fd [open [file join $confPath bookmark] r]
		while {1} {
			if {[gets $fd line]>0} {
				set ::BOOKMARK([lindex $line 0],state) 2
			}
			if [eof $fd] {close $fd ; break}
		}	
	} else {
		array set ::BOOKMARK ""
	}		
}


proc run_cmd {str} {
	global RESULT
	
	$RESULT tag remove match 1.0 end
	$RESULT tag remove mark  1.0 end
	if {$::result_clear} {$RESULT delete 1.0 end}
#	puts $str
	set ::snmp::cmd $str
	log_result "==== Start ====\n"
	update
	set line_num 1	
	if {$::start_macro_record} {	
		append ::macro_cmds $str\n		
	}
	
	if [catch {eval $str} ret] {
		log_result "Error: [string trim $ret]\n" err
		#return -code error
	} else {
		#puts ret=$ret
		binary scan $ret H* hex
		#puts ----------ret=$hex
		foreach line $ret {
			log_result "$line_num. $line\n"
			incr line_num 
		}
	}	
	log_result "==== Finish ====\n"
}


proc macro_gui {} {
	catch {destroy .macro}
	set p [toplevel .macro]
	bind $p <Escape> {destroy .macro}
	wm title $p "Macro"
	wm resizable $p 0 0 
	wm transient $p [winfo toplevel [winfo parent $p]]

	text $p.text -wrap none  -font $::result_font 
	set SH [::ttk::scrollbar $p.sh -orient horizontal -command [list $p.text xview]]
	set SV [::ttk::scrollbar $p.sv -orient vertical   -command [list $p.text yview]]
	$p.text configure -yscrollcommand [list $SV set]
	$p.text configure -xscrollcommand [list $SH set]
	
	ttk::frame $p.fr
	ttk::button $p.fr.bt1 -text Save   -command {
		set macrofile [tk_getSaveFile -initialdir $confPath/macro]
		if {$macrofile != ""} {
			set fd [open $macrofile w+]
			puts -nonewline $fd [.macro.text get 1.0 end]
			close $fd
			destroy .macro
		}		
	}
	ttk::button $p.fr.bt2 -text Cancel -command {destroy .macro}
	
	grid $p.text $SV -sticky "news"
	grid $SH -columnspan 2 -sticky "we"
	grid columnconfigure $p 0 -weight 1
	grid rowconfigure $p 0 -weight 1
	grid $p.fr -columnspan 2 
	grid $p.fr.bt1 -row 0 -column 1 -padx 10 -pady 5 
	grid $p.fr.bt2 -row 0 -column 0 -padx 10 -pady 5
	$p.text insert end $::macro_cmds ""	
	::tk::PlaceWindow $p 
	grab $p
}

proc run_macro {{filename ""}} {
	global confPath RESULT
	if {$::result_clear} {$RESULT delete 1.0 end}
	if {$filename!=""} {
		set macro $filename
	} else {
		set macro [tk_getOpenFile -initialdir $confPath/macro]
	}
	set break 0	
	set fd [open $macro r]
	if {$macro != ""} {
		log_result "==== Start Macro====\n"
		set line_num 1
		while {![eof $fd]} {
			if {[gets $fd line]>0} {
				if [catch {run_macro_cmd $line} ret] {
					log_result "Error in line $line_num: $line \n[string trim $ret ]" err
					log_result "==== Finish ====\n"
					set break 1
					break
				} else {
					log_result "$ret\n"
				}
			}
			incr line_num
		}
		close $fd
		set ::macro_is_running 0
	}
	if {!$break} {
		log_result "==== Finish ====\n"
	}
}

proc run_macro_cmd {str} {
	global RESULT
	set ::snmp::cmd_str $str
	$RESULT tag remove match 1.0 end
	$RESULT tag remove mark  1.0 end
	#if {$::result_clear} {$RESULT delete 1.0 end}
	#log_result "==== Start ====\n"
	update
	set line_num 1
	set run_str $str
	if {$::replace_macro_addr} {
		set addrstr [::snmp::addr]
		if {[lindex $str 0]=="snmp_set"} {
#			set strlst [lreplace $str end-3 end-3 "\[::snmp::addr\]"]
			set strlst [lreplace $str end-3 end-3 $addrstr]
#			set show_cmd [lreplace $str end-3 end-3 $addrstr]
			set show_cmd [lreplace $str end-3 end-3 $addrstr]
		} else {
#			set strlst [lreplace $str end-1 end-1 "\[::snmp::addr\]"]
			set strlst [lreplace $str end-1 end-1 $addrstr]
#			set show_cmd [lreplace $str end-1 end-1 [::snmp::addr]]
			set show_cmd [lreplace $str end-1 end-1 $addrstr]
		}
		set run_str [join $strlst]
	}
	
	log_result "$show_cmd\n" blue
	update
puts "run_str=$run_str"
	if [catch {eval $run_str} ret] {
		log_result "Error: [string trim $ret]\n" err
		return -code error
	} else {
		foreach line $ret {			
			log_result "\t[string trim $line]"
			incr line_num 
		}
	}	
	#log_result "==== Finish ====\n"
}

