#package require critcl

#critcl::cheaders -ggdb
critcl::clibraries -lgmp

critcl::cinit {
    mp_set_memory_functions((void*)MPZ_Alloc, (void*)MPZ_Realloc, (void*)MPZ_Free);
}

critcl::ccode {
    #include <tcl.h>
    #include <gmp.h>
    #include <stdio.h>
    #define TCL_MEM_DEBUG 1

    /*static gmp_randseed *rand_state = 0;*/

    /* wrapper to interface gmp's allocation with tcl's */
    void *MPZ_Alloc(int size) {
	void *mem;
#ifdef TCL_MEM_DEBUG
	mem = Tcl_DbCkalloc(size, __FILE__, __LINE__);
	Tcl_ValidateAllMemory(__FILE__, __LINE__)
#else
	mem = Tcl_Alloc(size);
#endif
	return mem;
    }

    /* wrapper to interface gmp's free with tcl's */
    void MPZ_Free(void *ptr, int size) {
#ifdef TCL_MEM_DEBUG
	Tcl_DbCkfree(ptr, __FILE__, __LINE__);
	Tcl_ValidateAllMemory(__FILE__, __LINE__)
#else
	Tcl_Free(ptr);
#endif
    }

    /* wrapper to interface gmp's realloc with tcl's */
    void *MPZ_Realloc(char *ptr, int old_size, int new_size) {
	void *mem;
#ifdef TCL_MEM_DEBUG
	mem = Tcl_DbCkrealloc(ptr, new_size, __FILE__, __LINE__);
	Tcl_ValidateAllMemory(__FILE__, __LINE__)
#else
	mem= Tcl_Realloc(ptr, new_size);
#endif
	return mem;
    }

    /* extract BigInt pointer from Tcl_Obj */
    #define GET_MPZ(obj) (*(mpz_t*)((obj)->internalRep.otherValuePtr))
    
    /* create a new BigInt */
    #define TclNewBigInt(objPtr) \
		   (objPtr) = MPZ_Alloc(sizeof(Tcl_Obj)); \
		       (objPtr)->refCount = 0; \
		       (objPtr)->bytes    = NULL; \
		       (objPtr)->length   = 0; \
		       (objPtr)->typePtr  = &BigInttype

    Tcl_ObjType BigInttype;

    /* Deallocate the storage associated with BigInt's internal representation.
    */
    static void freeBigInt(Tcl_Obj *objPtr)
    {
	/*fprintf(stderr, "freeBigInt (%04x", objPtr);*/
	mpz_clear(GET_MPZ(objPtr));
	/*fprintf(stderr, ") freeBigInt\n");*/
    }
    
    /* Initialize the internal representation of a BigInt 
    * to a copy of the internal representation of an existing
    * BigInt object. 
    */
    static void dupBigInt(Tcl_Obj *srcObj, Tcl_Obj *dupObj)
    {
	mpz_t *bn;
	/*fprintf(stderr, "dupBigInt (%04x <- %04x", srcObj, dupObj);*/
	bn = (mpz_t*)MPZ_Alloc(sizeof(mpz_t));
	dupObj->internalRep.otherValuePtr = bn ;
	mpz_init_set(*bn, GET_MPZ(srcObj));
	/*fprintf(stderr, ") dupBigInt\n");*/
    }
    
    /* Update the string representation for a BigInt data object.
    */
    static void
    updateBigInt(Tcl_Obj *objPtr)
    {
	/*fprintf(stderr, "updateBigInt (%04x", objPtr);*/
	objPtr->bytes = mpz_get_str (NULL, 10, GET_MPZ(objPtr));
	objPtr->length = strlen(objPtr->bytes);
	/*fprintf(stderr, ") updateBigInt\n");*/
    }
    
    static int doSetMPZ(Tcl_Obj *objPtr)
    {
	/*fprintf(stderr, "SetMPZ (%04x", objPtr);*/
	if (objPtr->typePtr != &BigInttype) {
	    int length;
	    char *src = Tcl_GetStringFromObj(objPtr, &length);
	    mpz_t *bn = (mpz_t*)MPZ_Alloc(sizeof(mpz_t));

	    if (mpz_init_set_str(*bn, src, 0) == 0) {
		objPtr->internalRep.otherValuePtr = bn;
		/*fprintf(stderr, ") SetMPZ OK\n");*/
		return 1;
	    } else {
		mpz_clear(*bn);
		/*fprintf(stderr, ") SetMPZ ERR\n");*/
		return 0;
	    }
	}
	/*fprintf(stderr, ") SetMPZ ID\n");*/
	return 1;
    }

    /* Generate BigInt internal rep from the string rep.
    */
    static int
    setBigInt(Tcl_Interp *interp, Tcl_Obj *objPtr)
    {
	if (doSetMPZ(objPtr)) {
	    return TCL_OK;
	} else {
	    return TCL_ERROR;
	}
    }
    
    Tcl_ObjType BigInttype = {
	"BigInt",
	freeBigInt,	/* free storage for the BigInt */
	dupBigInt,	/* create a new object as a copy of an existing object */
	updateBigInt,	/* update the string rep from the type's internal representation */
	setBigInt	/* convert the object's internal rep to this type */
    };
}

namespace eval bigint {}

foreach op {neg abs sqrt nextprime jacobi legendre kronecker} {
    eval [string map [list %OP% $op] {
	namespace eval bigint {
	    critcl::cproc %OP% {Tcl_Interp* interp Tcl_Obj* op1} ok {
		mpz_t *rop = (mpz_t*)MPZ_Alloc(sizeof(mpz_t));
		Tcl_Obj *objPtr;
		TclNewBigInt(objPtr);
	    
		mpz_init(*rop);
		objPtr->internalRep.otherValuePtr = rop;
		
		if (doSetMPZ(op1)) {
		    mpz_%OP%(*rop, GET_MPZ(op1));
		    
		    Tcl_SetObjResult(interp, objPtr);
		    return TCL_OK;
		} else {
		    return TCL_ERROR;
		}
	    }
	}
    }]
}

foreach op {add sub mul
    cdiv_q cdiv_r fdiv_q fdiv_r tdiv_q tdiv_r
    mod divexact sqrtrem gcd lcm invert remove
} {
    eval [string map [list %OP% $op] {
	namespace eval bigint {
	    critcl::cproc %OP% {Tcl_Interp* interp Tcl_Obj* op1 Tcl_Obj* op2} ok {
		mpz_t *rop = (mpz_t*)MPZ_Alloc(sizeof(mpz_t));
		Tcl_Obj *objPtr;
		TclNewBigInt(objPtr);
		
		mpz_init(*rop);
		objPtr->internalRep.otherValuePtr = rop;
		
		if (doSetMPZ(op1) && doSetMPZ(op2)) {
		    mpz_%OP%(*rop, GET_MPZ(op1), GET_MPZ(op2));
		    
		    Tcl_SetObjResult(interp, objPtr);
		    return TCL_OK;
		} else {
		    return TCL_ERROR;
		}
	    }
	}
    }]
}

foreach op {add sub mul
    cdiv_q cdiv_r fdiv_q fdiv_r tdiv_q tdiv_r
    mod divexact gcd lcm
} {
    eval [string map [list %OP% $op] {
	namespace eval bigint {
	    critcl::cproc %OP%_ui {Tcl_Interp* interp Tcl_Obj* op1 int op2} ok {
		mpz_t *rop = (mpz_t*)MPZ_Alloc(sizeof(mpz_t));
		Tcl_Obj *objPtr;
		TclNewBigInt(objPtr);

		mpz_init(*rop);
		objPtr->internalRep.otherValuePtr = rop;
		
		if (doSetMPZ(op1)) {
		    mpz_%OP%_ui(*rop, GET_MPZ(op1), op2);
		    
		    Tcl_SetObjResult(interp, objPtr);
		    return TCL_OK;
		} else {
		    return TCL_ERROR;
		}
	    }
	}
    }]
}
    
foreach op {cdiv_qr fdiv_qr tdiv_qr powm} {
    eval [string map [list %OP% $op] {
	namespace eval bigint {
	    critcl::cproc %OP% {Tcl_Interp* interp Tcl_Obj* op1 Tcl_Obj* op2 Tcl_Obj* op3} ok {
		mpz_t *rop = (mpz_t*)MPZ_Alloc(sizeof(mpz_t));
		Tcl_Obj *objPtr;
		TclNewBigInt(objPtr);
		
		mpz_init(*rop);
		objPtr->internalRep.otherValuePtr = rop;
		
		if (doSetMPZ(op1) && doSetMPZ(op2) && doSetMPZ(op3)) {
		    mpz_%OP%(*rop, GET_MPZ(op1), GET_MPZ(op2), GET_MPZ(op3));
		    
		    Tcl_SetObjResult(interp, objPtr);
		    return TCL_OK;
		} else {
		    return TCL_ERROR;
		}
	    }
	}
    }]
}

namespace eval bigint {
    critcl::cproc probab_prime_p {Tcl_Obj* rop int reps} int {
	doSetMPZ(rop);
	return mpz_probab_prime_p(GET_MPZ(rop), reps);
    }

    critcl::cproc sizeinbase {Tcl_Obj* rop int base} int {
	if (doSetMPZ(rop)) {
	    return mpz_sizeinbase(GET_MPZ(rop), base);
	} else {
	    return -1;
	}
    }

    critcl::cproc cmp {Tcl_Obj* op1 Tcl_Obj* op2} int {
	doSetMPZ(op1);
	doSetMPZ(op2);
	return mpz_cmp(GET_MPZ(op1), GET_MPZ(op2));
    }

    critcl::cproc cmp_ui {Tcl_Obj* op1 int op2} int {
	doSetMPZ(op1);
	return mpz_cmp_ui(GET_MPZ(op1), op2);
    }

    critcl::cproc cmp_si {Tcl_Obj* op1 int op2} int {
	doSetMPZ(op1);
	return mpz_cmp_si(GET_MPZ(op1), op2);
    }

    critcl::cproc cmpabs {Tcl_Obj* op1 Tcl_Obj* op2} int {
	doSetMPZ(op1);
	doSetMPZ(op2);
	return mpz_cmpabs(GET_MPZ(op1), GET_MPZ(op2));
    }

    critcl::cproc convert {Tcl_Interp* interp Tcl_Obj* obj} ok {
	if (doSetMPZ(obj)) {
	    Tcl_SetObjResult(interp, obj);
	    return TCL_OK;
	}
	return TCL_ERROR;
    }

    critcl::cproc hex {Tcl_Interp* interp Tcl_Obj* obj} ok {
	if (doSetMPZ(obj)) {
	    Tcl_SetResult(interp, mpz_get_str(NULL, 16, GET_MPZ(obj)), TCL_DYNAMIC);
	    return TCL_OK;
	}
	return TCL_ERROR;
    }

    namespace export *
}
