# PBKDF2 (Password-Based Key Derivation Function 2) 
# modify from http://wiki.tcl.tk/37331
# 1. change sha2 to sha1
# 2. support tcl8.4
 
namespace eval ::pbkdf2 {}

proc ::pbkdf2::pbkdf2 {password salt count dklen} {
	if {$::tcl_version>=8.5} {
		::pbkdf2::pbkdf2_85 $password $salt $count $dklen
	} else {
		::pbkdf2::pbkdf2_84 $password $salt $count $dklen
	}
}

proc ::pbkdf2::pbkdf2_85 {password salt count dklen} {
	set hlen 20 ;# sha1-hmac result -> 20 bytes
	if {$dklen > (2**32-1)*$hlen} { error "derived key too long" }
	set l [expr {int(ceil(double($dklen)/$hlen))}]
	set dkl [list]
	for {set i 1} {$i <= $l} {incr i} {
		set xsor [debin [set salty [::sha1::hmac -bin -key $password "$salt[binary format I $i]"]]]
		for {set j 1} {$j < $count} {incr j} { 
			set xsor [expr {$xsor ^ [debin [set salty [::sha1::hmac -bin -key $password $salty]]]}] 
		}
		lappend dkl $xsor
	}
	set dk [list]
	foreach dkp $dkl {
		set dkhl [list]				 
		while {$dkp > 0} {
			lappend dkhl [binary format Iu* [expr {$dkp & 0xFFFFFFFF}]]
			set dkp [expr {$dkp >> 32}]
		}			
		lappend dk [join [lreverse $dkhl] ""]
	}
	# return [string range [join $dk ""] 0 [incr dklen -1]]
	set ret [string range [join $dk ""] 0 [incr dklen -1]]
	binary scan $ret H* ret
	return $ret
}

proc ::pbkdf2::debin {vat} {
	binary scan $vat Iu* rl
	return [expr { ([lindex $rl 0] << 128) + ([lindex $rl 1] << 96) + ([lindex $rl 2] << 64) + ([lindex $rl 3] << 32) + [lindex $rl 4]}]
}

proc ::pbkdf2::xor {stra strb} {
	set len_a [string length $stra]
	set len_b [string length $strb]	
	if {$len_a != $len_b} {
		set pad [expr abs ($len_a - $len_b)]
		for {set i 0} {$i<$pad} {incr i} {
			append zero 0
		}
		if {$len_a>$len_b} {
			set strb $zero$strb
		} else {
			set stra $zero$stra
		}		
	}
	set len [string length $stra]
	for {set i 0} {$i<$len} {incr i} {
		append ret [format %x [expr 0x[string range $stra $i $i] ^ 0x[string range $strb $i $i]]]
	}	
	return $ret
}

proc ::pbkdf2::xor2 {stra strb} {
	binary scan $stra I* A
	binary scan $strb I* B
	for {set i 0} {$i<5} {incr i} {
		append ret [binary format I [expr [lindex $A $i] ^ [lindex $B $i]] ]		
	}
	return $ret
}

proc ::pbkdf2::pbkdf2_84 {password salt count dklen} {
	set hlen 20 ;# sha1-hmac result -> 20 bytes
	if {$dklen > [expr (pow(2,32)-1)*$hlen]} {
		error "derived key too long" 
	}
	set l [expr {int(ceil(double($dklen)/$hlen))}]	
	set dkl [list]

	for {set i 1} {$i <= $l} {incr i} {
		# set xsor [set salty [::sha1::hmac -hex -key $password "$salt[binary format I $i]"]]		
		set xsor [set salty [::sha1::hmac -bin -key $password "$salt[binary format I $i]"]]		
		for {set j 1} {$j < $count} {incr j} {			
			# set xsor [::pbkdf2::xor $xsor [set salty [::sha1::hmac -hex -key $password [binary format H* $salty]]]]
			set xsor [::pbkdf2::xor2 $xsor [set salty [::sha1::hmac -bin -key $password $salty]]]
		}
		lappend dkl $xsor
	}	
	set dk [list]
	foreach dkp $dkl {			 
		lappend dk $dkp
	}
	# return [string range [join $dk ""] 0 [expr $dklen*2-1]]
	set ret [string range [join $dk ""] 0 [incr dklen -1]]
	binary scan $ret H* ret
	return $ret
}