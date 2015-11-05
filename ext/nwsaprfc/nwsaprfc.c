/**************************************************************************************
*
*  nwsaprfc.c
*
*  sapnw and nwsaprfc.c are Copyright (c) 2006-2007 Piers Harding.  It is free software, and
*  may be redistributed under the terms specified in the README file of
*  the Ruby distribution.
*
**************************************************************************************/

#include <ruby.h>
#include <ruby/encoding.h>

/* SAP flag for Windows NT or 95 */
#ifdef _WIN32
#  ifndef SAPonNT
#    define SAPonNT
#  endif
#endif

#include <sapnwrfc.h>

#if defined(SAPonNT)
#include "windows.h"
#endif


/* fake up a definition of bool if it doesnt exist */
#ifndef bool
typedef SAP_RAW    bool;
#endif

/* create my true and false */
#ifndef false
typedef enum { false, true } mybool;
#endif

typedef struct SAPNW_CONN_INFO_rec {
                  RFC_CONNECTION_HANDLE handle;
                    RFC_CONNECTION_PARAMETER * loginParams;
                                    unsigned loginParamsLength;
                                    /*
                                    unsigned refs;
                                    */
} SAPNW_CONN_INFO;

typedef struct SAPNW_FUNC_DESC_rec {
                  RFC_FUNCTION_DESC_HANDLE handle;
                                    SAPNW_CONN_INFO * conn_handle;
                                    /*
                                    unsigned refs;
                                    */
                                    char * name;
                                    rb_encoding * name_enc;
} SAPNW_FUNC_DESC;

typedef struct SAPNW_FUNC_rec {
                  RFC_FUNCTION_HANDLE handle;
                                    SAPNW_FUNC_DESC * desc_handle;
} SAPNW_FUNC;


/* ruby module and class globals  */
VALUE mSAPNW,
      mSAPNW_RFC,
            cSAPNW_RFC_HANDLE,
            cSAPNW_RFC_SERVERHANDLE,
            cSAPNW_RFC_FUNCDESC,
            cSAPNW_RFC_FUNC_CALL,
            cSAPNW_RFC_CONNEXCPT,
            cSAPNW_RFC_SERVEXCPT,
            cSAPNW_RFC_FUNCEXCPT;

VALUE global_server_functions;

static VALUE get_field_value(DATA_CONTAINER_HANDLE hcont, RFC_FIELD_DESC fieldDesc);
void set_field_value(DATA_CONTAINER_HANDLE hcont, RFC_FIELD_DESC fieldDesc, VALUE value);
static VALUE get_table_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name);
void set_table_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value);


static void * make_space(int len){

    char * ptr;
    ptr = malloc( len + 1 );
    if ( ptr == NULL )
        return NULL;
    memset(ptr, 0, len + 1);
    return ptr;
}

/* copy the value of a parameter to a new pointer variable to be passed back onto the
   parameter pointer argument without the length supplied */
static void * make_strdup(VALUE value){

    char * ptr;
    //int len = RSTRING(value)->len;
    int len = RSTRING_LEN(value);
        ptr = make_space(len);
        memcpy((char *)ptr, StringValueCStr(value), len);
    return ptr;
}


/*
 *     RFC_RC SAP_API RfcUTF8ToSAPUC(const RFC_BYTE *utf8, unsigned utf8Length,  SAP_UC *sapuc,  unsigned *sapucSize, unsigned *resultLength, RFC_ERROR_INFO *info);
 *
*/

SAP_UC * u8to16c(char * str) {
  RFC_RC rc;
    RFC_ERROR_INFO errorInfo;
    SAP_UC *sapuc;
    unsigned sapucSize, resultLength;

  //sapucSize = strlen(str);
  sapucSize = strlen(str) + 1;
  //sapucSize = (2 * sapucSize) + 2;
  //sapucSize += MB_LEN_MAX + 2;
  sapuc = mallocU(sapucSize);
  memsetU(sapuc, 0, sapucSize);

    resultLength = 0;

  rc = RfcUTF8ToSAPUC((RFC_BYTE *)str, strlen(str), sapuc, &sapucSize, &resultLength, &errorInfo);
    return sapuc;
}


SAP_UC * u8to16(VALUE str) {
  RFC_RC rc;
    RFC_ERROR_INFO errorInfo;
    SAP_UC *sapuc;
    unsigned sapucSize, resultLength;

  //sapucSize = RSTRING(str)->len;
  //sapucSize = RSTRING(str)->len + 1;
  sapucSize = RSTRING_LEN(str) + 1;
  //sapucSize = (2 * sapucSize) + 2;
  //sapucSize += MB_LEN_MAX + 2;
  sapuc = mallocU(sapucSize);
  memsetU(sapuc, 0, sapucSize);

    resultLength = 0;

  //rc = RfcUTF8ToSAPUC((RFC_BYTE *)StringValueCStr(str), RSTRING(str)->len, sapuc, &sapucSize, &resultLength, &errorInfo);
  rc = RfcUTF8ToSAPUC((RFC_BYTE *)StringValueCStr(str), RSTRING_LEN(str), sapuc, &sapucSize, &resultLength, &errorInfo);
    return sapuc;
}


VALUE u16to8c(SAP_UC * str, int len) {
  RFC_RC rc;
    RFC_ERROR_INFO errorInfo;
    unsigned utf8Size, resultLength;
    char * utf8;
    VALUE rb_str;

  utf8Size = len * 4;
  utf8 = malloc(utf8Size + 2);
  memset(utf8, 0, utf8Size + 2);

    resultLength = 0;

  rc = RfcSAPUCToUTF8(str, len, (RFC_BYTE *)utf8, &utf8Size, &resultLength, &errorInfo);
  rb_str = rb_enc_str_new(utf8, resultLength, rb_utf8_encoding());
    free(utf8);
  return rb_str;
}


/*
    RFC_RC SAP_API RfcSAPUCToUTF8(const SAP_UC *sapuc,  unsigned sapucLength, RFC_BYTE *utf8, unsigned *utf8Size,  unsigned *resultLength, RFC_ERROR_INFO *info);
*/
VALUE u16to8(SAP_UC * str) {
  RFC_RC rc;
    RFC_ERROR_INFO errorInfo;
    unsigned utf8Size, resultLength;
    char * utf8;
    VALUE rb_str;

  utf8Size = strlenU(str) * 4;
  utf8 = malloc(utf8Size + 2);
  memset(utf8, 0, utf8Size + 2);

    resultLength = 0;

  rc = RfcSAPUCToUTF8(str, strlenU(str), (RFC_BYTE *)utf8, &utf8Size, &resultLength, &errorInfo);
  rb_str = rb_enc_str_new(utf8, resultLength, rb_utf8_encoding());
    free(utf8);
  return rb_str;
}


void SAPNW_rfc_conn_error(VALUE msg, VALUE code, VALUE key, VALUE message) {

  VALUE edata, e;

  e = rb_exc_new2(cSAPNW_RFC_CONNEXCPT, "RFC COMMUNICATION ERROR");
  edata = rb_hash_new();
  rb_hash_aset(edata, rb_str_new2("error"), msg);
  rb_hash_aset(edata, rb_str_new2("code"), code);
  rb_hash_aset(edata, rb_str_new2("key"), key);
  rb_hash_aset(edata, rb_str_new2("message"), message);
    rb_iv_set(e, "@error", edata);
  rb_exc_raise(e);
}


void SAPNW_rfc_serv_error(VALUE msg, VALUE code, VALUE key, VALUE message) {

  VALUE edata, e;

  e = rb_exc_new2(cSAPNW_RFC_SERVEXCPT, "RFC SERVER ERROR");
  edata = rb_hash_new();
  rb_hash_aset(edata, rb_str_new2("error"), msg);
  rb_hash_aset(edata, rb_str_new2("code"), code);
  rb_hash_aset(edata, rb_str_new2("key"), key);
  rb_hash_aset(edata, rb_str_new2("message"), message);
    rb_iv_set(e, "@error", edata);
  rb_exc_raise(e);
}


void SAPNW_rfc_call_error(VALUE msg, VALUE code, VALUE key, VALUE message) {

  VALUE edata, e;

  e = rb_exc_new2(cSAPNW_RFC_FUNCEXCPT, "RFC FUNCTION CALL ERROR");
  edata = rb_hash_new();
  rb_hash_aset(edata, rb_str_new2("error"), msg);
  rb_hash_aset(edata, rb_str_new2("code"), code);
  rb_hash_aset(edata, rb_str_new2("key"), key);
  rb_hash_aset(edata, rb_str_new2("message"), message);
    rb_iv_set(e, "@error", edata);
  rb_exc_raise(e);
}


VALUE conn_handle_close(SAPNW_CONN_INFO *ptr) {
  RFC_ERROR_INFO errorInfo;
  RFC_RC rc = RFC_OK;

  if (ptr == NULL || ptr->handle == NULL)
        return Qtrue;

  rc = RfcCloseConnection(ptr->handle, &errorInfo);
    /* fprintf(stderr, "conn_handle_close called\n"); */
  ptr->handle = NULL;
  if (rc != RFC_OK) {
      SAPNW_rfc_conn_error(rb_str_new2("Problem closing RFC connection handle"),
                           INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                               u16to8(errorInfo.message));
        return Qnil;
    } else {
        return Qtrue;
    }
}


static void conn_handle_mark (SAPNW_CONN_INFO *ptr)
{
  /* fprintf(stderr, "conn_handle_mark: %p - %p\n", ptr, ptr->handle); */
}


static void conn_handle_free (SAPNW_CONN_INFO *ptr)
{
  /* fprintf(stderr, "conn_handle_free: -> start %p - %p\n", ptr, ptr->handle); */
    if (ptr->handle != NULL) {
     /* close RFC Connection first */
    /* fprintf(stderr, "conn_handle_free: -> closing RFC connection\n"); */
        conn_handle_close(ptr);
    }

    /*
    if (ptr->refs != 0) {
      fprintf(stderr, "Still have FUNC_CONN references in FUNC_DESCs (%d) \n", ptr->refs);
        exit(-1);
    }
    */
    free(ptr);
  /* fprintf(stderr, "conn_handle_free: -> finished\n"); */
}


/* allocate a new RFC_FIELD_DESC to be subsequently used in types, structures, and parameters */
RFC_FIELD_DESC * SAPNW_alloc_field(SAP_UC * name, RFCTYPE type, unsigned nucLength, unsigned nucOffset, unsigned ucLength, unsigned ucOffset, unsigned decimals, RFC_TYPE_DESC_HANDLE typeDescHandle, void* extendedDescription) {

    RFC_FIELD_DESC * fieldDesc;
    SAP_UC * useless_void;

#ifdef _win32
    fprintfU(stderr, cU("alloc_field: %s\n"), name);
#endif
    fieldDesc = malloc(sizeof(RFC_FIELD_DESC));
    memset(fieldDesc, 0,sizeof(RFC_FIELD_DESC));

    useless_void = memcpyU(fieldDesc->name, name, (size_t)strlenU(name));
    fieldDesc->type = type;
    fieldDesc->nucLength = nucLength;
    fieldDesc->nucOffset = nucOffset;
    fieldDesc->ucLength = ucLength;
    fieldDesc->ucOffset = ucOffset;
    fieldDesc->decimals = decimals;
    fieldDesc->typeDescHandle = typeDescHandle;
    fieldDesc->extendedDescription = extendedDescription;

  return fieldDesc;
}


/* allocate a new RFC_PARAMETER-DESC to be subsequently used in an interface description */
RFC_TYPE_DESC_HANDLE SAPNW_alloc_type(SAP_UC * name) {

    RFC_TYPE_DESC_HANDLE typeDesc;
  RFC_ERROR_INFO errorInfo;

#ifdef _WIN32
    fprintfU(stderr, cU("alloc_type: %s\n"), name);
#endif
    typeDesc = RfcCreateTypeDesc(name, &errorInfo);

  /* bail on a bad return code */
  if (typeDesc == NULL) {
        SAPNW_rfc_serv_error(rb_str_concat(rb_str_new2("Problem with RfcCreateTypeDesc: "), u16to8(name)),
                           INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                               u16to8(errorInfo.message));
    }

  return typeDesc;
}


/* allocate a new RFC_PARAMETER-DESC to be subsequently used in an interface description */
RFC_TYPE_DESC_HANDLE SAPNW_build_type(VALUE name, VALUE fields) {

    RFC_TYPE_DESC_HANDLE typeDesc;
    RFC_TYPE_DESC_HANDLE field_type_desc;
    SAP_UC * pname;
    SAP_UC * pfname;
  RFC_ERROR_INFO errorInfo;
  RFC_RC rc = RFC_OK;
    unsigned i, off, uoff;
    VALUE field, fname, ftype, flen, fulen, fdecimals, type_name, type_fields, ptypedef;
    RFC_ABAP_NAME abap_name;

#ifdef _win32
    fprintf(stderr, "build_type: %s\n", stringvaluecstr(name));
#endif
    typeDesc = SAPNW_alloc_type((pname = u8to16(name)));
#ifdef _win32
    fprintf(stderr, "build_type: after alloc_type\n");
#endif
    free(pname);
    RfcGetTypeName(typeDesc, abap_name, &errorInfo);
    //fprintfU(stderr, cU("creating type: %s\n"), abap_name);

  off = 0;
    uoff = 0;
  Check_Type(fields, T_ARRAY);
    //fprintf(stderr, "Have %d fields\n", (int) RARRAY(fields)->len);
    //for (i = 0; i < RARRAY(fields)->len; i++) {
    for (i = 0; i < RARRAY_LEN(fields); i++) {
    field = rb_ary_entry(fields, i);
    Check_Type(field, T_HASH);
    fname = rb_hash_aref(field, ID2SYM(rb_intern("name")));
    ftype = rb_hash_aref(field, ID2SYM(rb_intern("type")));
    flen = rb_hash_aref(field, ID2SYM(rb_intern("len")));
    fulen = rb_hash_aref(field, ID2SYM(rb_intern("ulen")));
    fdecimals = rb_hash_aref(field, ID2SYM(rb_intern("decimals")));
      //fprintf(stderr, "got field vals: %s len: %d ulen: %d dec: %d\n", StringValueCStr(fname), (int) NUM2INT(flen), (int) NUM2INT(fulen), (int) NUM2INT(fdecimals));
      if (NUM2INT(ftype) == RFCTYPE_STRUCTURE ||
          NUM2INT(ftype) == RFCTYPE_TABLE) {
            //fprintf(stderr, "Field has complex type\n");
      ptypedef = rb_hash_aref(field, ID2SYM(rb_intern("typedef")));
            if (ptypedef == Qnil) {
              fprintf(stderr, "Field does not have typedef - %s\n", StringValueCStr(fname));
                exit(1);
            }
      type_name = rb_iv_get(ptypedef, "@name");
      type_fields = rb_iv_get(ptypedef, "@fields");
            if (type_fields == Qnil) {
              fprintf(stderr, "Field (%s) does not have @fields - %s\n", StringValueCStr(fname), StringValueCStr(type_name));
                exit(1);
            }
      field_type_desc = SAPNW_build_type(type_name, type_fields);
          //fprintf(stderr, "created the type\n");
        rc = RfcAddTypeField(typeDesc, SAPNW_alloc_field((pfname = u8to16(fname)),
                               NUM2INT(ftype), NUM2INT(flen), off, NUM2INT(fulen),
                                                   uoff, NUM2INT(fdecimals), field_type_desc, NULL), &errorInfo);
      } else {
        rc = RfcAddTypeField(typeDesc, SAPNW_alloc_field((pfname = u8to16(fname)),
                               NUM2INT(ftype), NUM2INT(flen), off, NUM2INT(fulen),
                                                   uoff, NUM2INT(fdecimals), NULL, NULL), &errorInfo);
        }
        free(pfname);
    if (rc != RFC_OK) {
           SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem RfcAddTypeField: "), name),
                                INT2NUM(errorInfo.code),
                                                    u16to8(errorInfo.key),
                                              u16to8(errorInfo.message));
    }
        off += NUM2INT(flen);
        uoff += NUM2INT(fulen);
    }

    //fprintf(stderr, "Finished the fields - total: %d - %d\n", off, uoff);

    rc = RfcSetTypeLength(typeDesc, off, uoff, &errorInfo);
  if (rc != RFC_OK) {
        SAPNW_rfc_serv_error(rb_str_concat(rb_str_new2("Problem with RfcSetTypeLength: "), name),
                           INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                               u16to8(errorInfo.message));
    }

    //fprintf(stderr, "finished type desc\n");
#ifdef _win32
    fprintf(stderr, "build_type: finished\n");
#endif
  return typeDesc;
}


/* allocate a new RFC_PARAMETER-DESC to be subsequently used in an interface description */
RFC_PARAMETER_DESC * SAPNW_alloc_parameter(SAP_UC * name, RFCTYPE type, RFC_DIRECTION direction, unsigned nucLength, unsigned ucLength, unsigned decimals, RFC_TYPE_DESC_HANDLE typeDescHandle, void* extendedDescription) {

    RFC_PARAMETER_DESC * parameterDesc;
    SAP_UC * useless_void;

    parameterDesc = malloc(sizeof(RFC_PARAMETER_DESC));
    memset(parameterDesc, 0,sizeof(RFC_PARAMETER_DESC));
    switch (direction) {
        case 1:
            direction = RFC_EXPORT;
            break;
        case 2:
            direction = RFC_IMPORT;
            break;
        default:
            break;
    }

    useless_void = memcpyU(parameterDesc->name, name, (size_t)strlenU(name));
    parameterDesc->type = type;
    parameterDesc->direction = direction;
    parameterDesc->nucLength = nucLength;
    parameterDesc->ucLength = ucLength;
    parameterDesc->decimals = decimals;
    parameterDesc->typeDescHandle = typeDescHandle;
    parameterDesc->extendedDescription = extendedDescription;

  return parameterDesc;
}


/* build a connection to an SAP system */
/*
 * must call this from within Base.connect
 *   in Base.connect it allocates empty SAPNW::Handle which gets tainted with the handle struct
 *   this then becomes an attribute of a new SAPNW::Connection which should also
 *   contain a copy of the connection parameters used to make the connection - incase a reconnect is needed
 */

static VALUE  SAPNW_RFC_HANDLE_new(VALUE class, VALUE connobj){

  RFC_ERROR_INFO errorInfo;
  VALUE handle, connParms, hval, parm;
    SAPNW_CONN_INFO *hptr;
    RFC_CONNECTION_PARAMETER * loginParams;
    int idx, i;
    bool server;

    hptr = ALLOC(SAPNW_CONN_INFO);
    hptr->handle = NULL;
    /*
    hptr->refs = 0;
    */

  connParms = rb_iv_get(connobj, "@connection_parameters");
  Check_Type(connParms, T_ARRAY);

  //idx = RARRAY(connParms)->len;
  idx = RARRAY_LEN(connParms);
    if (idx == 0) {
      rb_raise(rb_eRuntimeError, "No connection parameters\n");
    }

    loginParams = malloc(idx*sizeof(RFC_CONNECTION_PARAMETER));
    memset(loginParams, 0,idx*sizeof(RFC_CONNECTION_PARAMETER));

  server = false;
    for (i = 0; i < idx; i++) {
     parm = rb_ary_entry(connParms, i);
     hval = rb_hash_aref(parm,rb_str_new2("name"));
         if (strcmp(StringValueCStr(hval), "tpname") == 0)
           server = true;
     loginParams[i].name = (SAP_UC *) u8to16(hval);
     //fprintfU(stderr, cU("Conn parameter name: %s#\n"), loginParams[i].name);
     hval = rb_hash_aref(parm,rb_str_new2("value"));
     loginParams[i].value = (SAP_UC *) u8to16(hval);
     //fprintfU(stderr, cU("Conn parameter value: %s#\n"), loginParams[i].value);
  }

  if (server) {
      //fprintf(stderr, "RfcRegisterServer ...\n");
      hptr->handle = RfcRegisterServer(loginParams, idx, &errorInfo);
        hptr->loginParams = loginParams;
        hptr->loginParamsLength = idx;
    } else {
      hptr->handle = RfcOpenConnection(loginParams, idx, &errorInfo);
    };

    if (! server || hptr->handle == NULL) {
        hptr->loginParams = NULL;
        hptr->loginParamsLength = 0;
      for (i = 0; i < idx; i++) {
       free((char *) loginParams[i].name);
       free((char *) loginParams[i].value);
    }
      free(loginParams);
    }
    if (hptr->handle == NULL) {
      SAPNW_rfc_conn_error(rb_str_new2("RFC connection open failed "),
                           INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                               u16to8(errorInfo.message));
        return Qnil;
    }
  /* fprintf(stderr, "Created conn_handle: %p - %p\n", hptr, hptr->handle); */

    handle = Data_Wrap_Struct(class,
                              conn_handle_mark,
                                                      conn_handle_free,
                                                      hptr);

  rb_iv_set(connobj, "@handle", handle);
  return handle;

}


/* Disconnect from an SAP system */
static VALUE SAPNW_RFC_HANDLE_close(VALUE self){

  SAPNW_CONN_INFO *ptr;

  /* fprintf(stderr, "in handle EXPLICIT close\n"); */
    Data_Get_Struct(self, SAPNW_CONN_INFO, ptr);
  return conn_handle_close(ptr);
}


/* ping the SAP system */
static VALUE SAPNW_RFC_HANDLE_ping(VALUE self){

  SAPNW_CONN_INFO *ptr;
  RFC_ERROR_INFO errorInfo;
  RFC_RC rc = RFC_OK;

  Data_Get_Struct(self, SAPNW_CONN_INFO, ptr);

  if (ptr == NULL || ptr->handle == NULL) {
        return Qnil;
  }
  rc = RfcPing(ptr->handle, &errorInfo);
  if (rc != RFC_OK) {
        return Qnil;
  } else {
       return Qtrue;
  }
}


/* Get the attributes of a connection handle */
static VALUE SAPNW_RFC_HANDLE_connection_attributes(VALUE self){

  SAPNW_CONN_INFO *hptr;
    RFC_ATTRIBUTES attribs;
  RFC_ERROR_INFO errorInfo;
    VALUE attrib_hash;
    RFC_RC rc = RFC_OK;

  /* fprintf(stderr, "in connection_attributes\n"); */
    Data_Get_Struct(self, SAPNW_CONN_INFO, hptr);

    rc = RfcGetConnectionAttributes(hptr->handle, &attribs, &errorInfo);

  /* bail on a bad return code */
  if (rc != RFC_OK) {
      SAPNW_rfc_conn_error(rb_str_new2("getting connection attributes "),
                           INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                               u16to8(errorInfo.message));
        return Qnil;
    }

  /* else return a hash of connection attributes */
    attrib_hash = rb_hash_new();
  rb_hash_aset(attrib_hash, rb_str_new2("dest"), u16to8(attribs.dest));
  rb_hash_aset(attrib_hash, rb_str_new2("host"), u16to8(attribs.host));
  rb_hash_aset(attrib_hash, rb_str_new2("partnerHost"), u16to8(attribs.partnerHost));
  rb_hash_aset(attrib_hash, rb_str_new2("sysNumber"), u16to8(attribs.sysNumber));
  rb_hash_aset(attrib_hash, rb_str_new2("sysId"), u16to8(attribs.sysId));
  rb_hash_aset(attrib_hash, rb_str_new2("client"), u16to8(attribs.client));
  rb_hash_aset(attrib_hash, rb_str_new2("user"), u16to8(attribs.user));
  rb_hash_aset(attrib_hash, rb_str_new2("language"), u16to8(attribs.language));
  rb_hash_aset(attrib_hash, rb_str_new2("trace"), u16to8(attribs.trace));
  rb_hash_aset(attrib_hash, rb_str_new2("isoLanguage"), u16to8(attribs.isoLanguage));
  rb_hash_aset(attrib_hash, rb_str_new2("codepage"), u16to8(attribs.codepage));
  rb_hash_aset(attrib_hash, rb_str_new2("partnerCodepage"), u16to8(attribs.partnerCodepage));
  rb_hash_aset(attrib_hash, rb_str_new2("rfcRole"), u16to8(attribs.rfcRole));
  rb_hash_aset(attrib_hash, rb_str_new2("type"), u16to8(attribs.type));
  rb_hash_aset(attrib_hash, rb_str_new2("rel"), u16to8(attribs.rel));
  rb_hash_aset(attrib_hash, rb_str_new2("partnerType"), u16to8(attribs.partnerType));
  rb_hash_aset(attrib_hash, rb_str_new2("partnerRel"), u16to8(attribs.partnerRel));
  rb_hash_aset(attrib_hash, rb_str_new2("kernelRel"), u16to8(attribs.kernelRel));
  rb_hash_aset(attrib_hash, rb_str_new2("cpicConvId"), u16to8(attribs.cpicConvId));
  rb_hash_aset(attrib_hash, rb_str_new2("progName"), u16to8(attribs.progName));

  return attrib_hash;
}


/* Get the attributes of a connection handle */
static VALUE SAPNW_RFC_HANDLE_reset_server_context(VALUE self){

  SAPNW_CONN_INFO *hptr;

    Data_Get_Struct(self, SAPNW_CONN_INFO, hptr);
    /*
     * XXX to be activated when SAP release
    RfcResetServerContext(hptr->handle, NULL);
    */

    return Qtrue;
}


/* build a connection to an SAP system */
/*
 * must call this from within Base.connect
 *   in Base.connect it allocates empty SAPNW::Handle which gets tainted with the handle struct
 *   this then becomes an attribute of a new SAPNW::Connection which should also
 *   contain a copy of the connection parameters used to make the connection - incase a reconnect is needed
 */

static VALUE  SAPNW_RFC_SERVERHANDLE_new(VALUE class, VALUE connobj){

  return SAPNW_RFC_HANDLE_new(class, connobj);
}


/* Get the attributes of a connection handle */
static VALUE SAPNW_RFC_SERVERHANDLE_connection_attributes(VALUE self){

  return SAPNW_RFC_HANDLE_connection_attributes(self);
}


/* Disconnect from an SAP system */
static VALUE SAPNW_RFC_SERVERHANDLE_close(VALUE self){

  return SAPNW_RFC_HANDLE_close(self);
}


/* Disconnect from an SAP system */
static VALUE SAPNW_RFC_SERVERHANDLE_accept(VALUE self, VALUE wait, VALUE global_callback){

    RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
  SAPNW_CONN_INFO *hptr;
    VALUE result;

  /* fprintf(stderr, "in connection_attributes\n"); */
    Data_Get_Struct(self, SAPNW_CONN_INFO, hptr);

    if (TYPE(wait) != T_FIXNUM)
        rb_raise(rb_eRuntimeError, "wait value for server.accept must be a FIXNUM type\n");

    while(RFC_OK == rc || RFC_RETRY == rc || RFC_ABAP_EXCEPTION == rc){
        rc = RfcListenAndDispatch(hptr->handle, NUM2INT(wait), &errorInfo);

    /* jump out of the accept loop on command */
        if (rc == RFC_CLOSED) {
          break;
        }

        switch (rc){
            case RFC_RETRY:    // This only notifies us, that no request came in within the timeout period.
                            // We just continue our loop.
                break;
            case RFC_NOT_FOUND:    // R/3 tried to invoke a function module, for which we did not supply
                                // an implementation. R/3 has been notified of this through a SYSTEM_FAILURE,
                                // so we need to refresh our connection.
            case RFC_ABAP_MESSAGE:        // And in this case a fresh connection is needed as well
                hptr->handle = RfcRegisterServer(hptr->loginParams, hptr->loginParamsLength, &errorInfo);
                rc = errorInfo.code;
                break;
            case RFC_ABAP_EXCEPTION:    // Our function module implementation has returned RFC_ABAP_EXCEPTION.
                                // This is equivalent to an ABAP function module throwing an ABAP Exception.
                                // The Exception has been returned to R/3 and our connection is still open.
                                // So we just loop around.
                break;
            case RFC_OK:
              break;
          default:
            fprintf(stderr, "This return code is not implemented (%d) - abort\n", rc);
              exit(1);
            break;
        }

        /* invoke the global callback */
      result = rb_funcall(rb_path2class("SAPNW::RFC::Server"), rb_intern("handler"), 2, global_callback, SAPNW_RFC_SERVERHANDLE_connection_attributes(self));
      if (result == Qnil || result == Qfalse) {
        /* the callback has asked for termination */
           break;
      }
    }


  return Qtrue;
}


/* Disconnect from an SAP system */
static VALUE SAPNW_RFC_SERVERHANDLE_process(VALUE self, VALUE wait){

    RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
  SAPNW_CONN_INFO *hptr;

  /* fprintf(stderr, "in connection_attributes\n"); */
    Data_Get_Struct(self, SAPNW_CONN_INFO, hptr);

    if (TYPE(wait) != T_FIXNUM)
        rb_raise(rb_eRuntimeError, "wait value for server.accept must be a FIXNUM type\n");

    rc = RfcListenAndDispatch(hptr->handle, NUM2INT(wait), &errorInfo);

  /* jump out of the accept loop on command */
    if (rc == RFC_CLOSED) {
      return INT2NUM(rc);
    }

    switch (rc){
        case RFC_RETRY:    // This only notifies us, that no request came in within the timeout period.
                        // We just continue our loop.
            break;
        case RFC_NOT_FOUND:    // R/3 tried to invoke a function module, for which we did not supply
                            // an implementation. R/3 has been notified of this through a SYSTEM_FAILURE,
                            // so we need to refresh our connection.
        case RFC_ABAP_MESSAGE:        // And in this case a fresh connection is needed as well
            hptr->handle = RfcRegisterServer(hptr->loginParams, hptr->loginParamsLength, &errorInfo);
            //rc = errorInfo.code;
            break;
        case RFC_ABAP_EXCEPTION:    // Our function module implementation has returned RFC_ABAP_EXCEPTION.
                            // This is equivalent to an ABAP function module throwing an ABAP Exception.
                            // The Exception has been returned to R/3 and our connection is still open.
                            // So we just loop around.
            break;
        case RFC_OK:
          break;
      default:
        fprintf(stderr, "This return code is not implemented (%d) - abort\n", rc);
          exit(1);
        break;
    }

  return INT2NUM(rc);
}


static void func_desc_handle_mark (SAPNW_FUNC_DESC *ptr)
{
  /* fprintf(stderr, "func_desc_handle_mark: %p\n", ptr); */
}


static void func_desc_handle_free (SAPNW_FUNC_DESC *ptr)
{
  RFC_ERROR_INFO errorInfo;
  RFC_RC rc = RFC_OK;
    /*
    VALUE errkey, errmsg;
    */

  /* fprintf(stderr, "func_desc_handle_free: -> start %p\n", ptr); */
  rc = RfcDestroyFunctionDesc(ptr->handle, &errorInfo);
    ptr->handle = NULL;
    /*
  if (rc != RFC_OK) {
      fprintfU(stderr, cU("RFC ERR %s: %s\n"), errorInfo.key, errorInfo.message);
    errkey = u16to8(ptr->conn_handle, errorInfo.key); errmsg = u16to8(ptr->conn_handle, errorInfo.message);
        rb_raise(rb_eRuntimeError, "Problem in RfcDestroyFunctionDesc code: %d key: %s message: %s\n",
                                   errorInfo.code, StringValueCStr(errkey), StringValueCStr(errmsg));
    }
 */
    /*
    ptr->conn_handle->refs --;
    */
    ptr->conn_handle = NULL;
    free(ptr->name);
    /*
    if (ptr->refs != 0) {
      fprintf(stderr, "Still have FUNC_DESC references in FUNC_CALLs (%d) \n", ptr->refs);
        exit(-1);
    }
    */
    free(ptr);
  /* fprintf(stderr, "func_desc_handle_free: -> finished\n"); */
}


static VALUE  SAPNW_RFC_FUNCDESC_new(VALUE class, VALUE func){

    SAPNW_FUNC_DESC *dptr;
    RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    VALUE function_def;
    SAP_UC * fname;
    RFC_FUNCTION_DESC_HANDLE func_desc_handle;
    RFC_ABAP_NAME func_name;

  func_desc_handle = RfcCreateFunctionDesc((fname = u8to16(func)), &errorInfo);
  /* bail on a bad lookup */
  if (func_desc_handle == NULL) {
        SAPNW_rfc_conn_error(rb_str_concat(rb_str_new2("Problem with RfcCreateFunctionDesc: "), func),
                           INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                               u16to8(errorInfo.message));
        return Qnil;
    }
    free(fname);

  /* wrap in SAPNW::RFC::FunctionDescriptor  Object */
    dptr = ALLOC(SAPNW_FUNC_DESC);
    dptr->handle = func_desc_handle;
    dptr->conn_handle = NULL;
    /*
    dptr->refs = 0;
    dptr->conn_handle->refs ++;
    */
    dptr->name = make_strdup(func);
    dptr->name_enc = rb_enc_get(func);
    function_def = Data_Wrap_Struct(class,
                                    func_desc_handle_mark,
                                                            func_desc_handle_free,
                                                            dptr);

  /* read back the function name */
    rc = RfcGetFunctionName(dptr->handle, func_name, &errorInfo);

  /* bail on a bad RfcGetFunctionName */
  if (rc != RFC_OK) {
      SAPNW_rfc_conn_error(rb_str_concat(rb_str_new2("(FunctionDescriptor.new)Problem in RfcGetFunctionName: "), func),
                           INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                               u16to8(errorInfo.message));
        return Qnil;
    }
  rb_iv_set(function_def, "@name", u16to8(func_name));
  rb_iv_set(function_def, "@parameters", rb_hash_new());
  rb_iv_set(function_def, "@callback", Qnil);

  return function_def;
}


/* Get the Metadata description of a Function Module */
static VALUE SAPNW_RFC_HANDLE_function_lookup(VALUE self, VALUE class, VALUE parm_class, VALUE func){

  SAPNW_CONN_INFO *hptr;
    SAPNW_FUNC_DESC *dptr;
    RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    VALUE function_def, parm_name;
    SAP_UC * fname;
    RFC_FUNCTION_DESC_HANDLE func_desc_handle;
    RFC_ABAP_NAME func_name;
    RFC_PARAMETER_DESC parm_desc;
    unsigned parm_count;
    int i;

    Data_Get_Struct(self, SAPNW_CONN_INFO, hptr);

    func_desc_handle = RfcGetFunctionDesc(hptr->handle, (fname = u8to16(func)), &errorInfo);
    free((char *)fname);

  /* bail on a bad lookup */
  if (func_desc_handle == NULL) {
        SAPNW_rfc_conn_error(rb_str_concat(rb_str_new2("Problem looking up RFC: "), func),
                           INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                               u16to8(errorInfo.message));
        return Qnil;
    }

  /* wrap in SAPNW::RFC::FunctionDescriptor  Object */
    dptr = ALLOC(SAPNW_FUNC_DESC);
    dptr->handle = func_desc_handle;
    dptr->conn_handle = hptr;
    /*
    dptr->refs = 0;
    dptr->conn_handle->refs ++;
    */
    dptr->name = make_strdup(func);
    dptr->name_enc = rb_enc_get(func);
    function_def = Data_Wrap_Struct(class,
                                    func_desc_handle_mark,
                                                            func_desc_handle_free,
                                                            dptr);

  /* read back the function name */
    rc = RfcGetFunctionName(dptr->handle, func_name, &errorInfo);

  /* bail on a bad RfcGetFunctionName */
  if (rc != RFC_OK) {
      SAPNW_rfc_conn_error(rb_str_concat(rb_str_new2("Problem in RfcGetFunctionName: "), func),
                           INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                               u16to8(errorInfo.message));
        return Qnil;
    }
  rb_iv_set(function_def, "@name", u16to8(func_name));

  /* Get the parameter details */
    rc = RfcGetParameterCount(dptr->handle, &parm_count, &errorInfo);

  /* bail on a bad RfcGetParameterCount */
  if (rc != RFC_OK) {
      SAPNW_rfc_conn_error(rb_str_concat(rb_str_new2("Problem in RfcGetParameterCount: "), func),
                           INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                               u16to8(errorInfo.message));
        return Qnil;
    }

  /* fprintf(stderr, "number of parameters: %d\n", parm_count); */
  rb_iv_set(function_def, "@parameters", rb_hash_new());
    for (i = 0; i < parm_count; i++) {
      rc = RfcGetParameterDescByIndex(dptr->handle, i, &parm_desc, &errorInfo);
    /* bail on a bad RfcGetParameterDescByIndex */
    if (rc != RFC_OK) {
          SAPNW_rfc_conn_error(rb_str_concat(rb_str_new2("Problem in RfcGetParameterDescByIndex: "), func),
                               INT2NUM(errorInfo.code),
                                                   u16to8(errorInfo.key),
                                                   u16to8(errorInfo.message));
          return Qnil;
      }

        /* create a new parameter obj */
        //fprintfU(stderr, cU("Parameter (%d): %s - direction: (%d) - type(%d)\n"), i, parm_desc.name, parm_desc.direction, parm_desc.type);
    parm_name = u16to8(parm_desc.name);

    rb_funcall(function_def, rb_intern("addParameter"), 6,
                   parm_name, INT2NUM(parm_desc.direction),
                             INT2NUM(parm_desc.type), INT2NUM(parm_desc.nucLength),
                             INT2NUM(parm_desc.ucLength), INT2NUM(parm_desc.decimals));
  }

  return function_def;
}


static void func_call_handle_mark (SAPNW_FUNC *ptr)
{
  /* fprintf(stderr, "func_call_handle_mark: %p\n", ptr); */
}


static void func_call_handle_free (SAPNW_FUNC *ptr)
{
  RFC_ERROR_INFO errorInfo;
  RFC_RC rc = RFC_OK;

  /* fprintf(stderr, "func_call_handle_free: -> start %p\n", ptr); */
  rc = RfcDestroyFunction(ptr->handle, &errorInfo);
    ptr->handle = NULL;
  if (rc != RFC_OK) {
        SAPNW_rfc_conn_error(rb_str_concat(rb_str_new2("Problem in RfcDesctroyFunction: "),
                                           rb_enc_str_new(ptr->desc_handle->name,
                                                          strlen(ptr->desc_handle->name),
                                                          ptr->desc_handle->name_enc)),
                             INT2NUM(errorInfo.code),
                                                 u16to8(errorInfo.key),
                                                 u16to8(errorInfo.message));
    }
    /*
    ptr->desc_handle->refs --;
    */
    ptr->desc_handle = NULL;
    free(ptr);
  /* fprintf(stderr, "func_handle_free: -> finished\n"); */
}


/* Create a Function Module handle to be used for an RFC call */
static VALUE SAPNW_RFC_FUNCDESC_create_function_call(VALUE self, VALUE class){

    SAPNW_FUNC_DESC *dptr;
    SAPNW_FUNC *fptr;
  RFC_ERROR_INFO errorInfo;
    RFC_FUNCTION_HANDLE func_handle;
    VALUE function;

  /* fprintf(stderr, "in handle create_function\n"); */
    Data_Get_Struct(self, SAPNW_FUNC_DESC, dptr);

    func_handle = RfcCreateFunction(dptr->handle, &errorInfo);

  /* bail on a bad lookup */
  if (func_handle == NULL) {
        SAPNW_rfc_conn_error(rb_str_concat(rb_str_new2("Problem Creating Function Data Container RFC: "),
                                           rb_enc_str_new(dptr->name,strlen(dptr->name),dptr->name_enc)),
                             INT2NUM(errorInfo.code),
                                                 u16to8(errorInfo.key),
                                                 u16to8(errorInfo.message));
        return Qnil;
    }

  /* wrap in SAPNW::RFC::FunctionCall  Object */
    fptr = ALLOC(SAPNW_FUNC);
    fptr->handle = func_handle;
    fptr->desc_handle = dptr;
    /*
    fptr->desc_handle->refs ++;
    */
    function = Data_Wrap_Struct(class,
                                func_call_handle_mark,
                                                    func_call_handle_free,
                                                    fptr);
  rb_iv_set(function, "@name", rb_enc_str_new(dptr->name,strlen(dptr->name),dptr->name_enc));
  rb_iv_set(function, "@function_descriptor", self);

  //rb_iv_set(function, "@parameters", rb_hash_new());
  rb_funcall(function, rb_intern("initialize"), 0);

  return function;
}


/* Create a Function Module handle to be used for an RFC call */
static VALUE SAPNW_RFC_FUNCDESC_enable_XML(VALUE self){

    SAPNW_FUNC_DESC *dptr;
  RFC_ERROR_INFO errorInfo;
  RFC_RC rc = RFC_OK;

  /* fprintf(stderr, "in handle create_function\n"); */
    Data_Get_Struct(self, SAPNW_FUNC_DESC, dptr);

  rc = RfcEnableBASXML(dptr->handle, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcEnableBASXML: "),
                                         rb_enc_str_new(dptr->name,strlen(dptr->name),dptr->name_enc)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }
  return Qtrue;
}


/* Create a Function Module handle to be used for an RFC call */
static VALUE SAPNW_RFC_FUNCDESC_add_parameter(VALUE self, VALUE parameter){

    SAPNW_FUNC_DESC *dptr;
  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    VALUE name, type, direction, nucLength, ucLength, decimals, fields, ptypedef, type_name;
    SAP_UC * pname;
  RFC_PARAMETER_DESC * parm_desc;
    RFC_TYPE_DESC_HANDLE type_desc;

#ifdef _WIN32
  fprintf(stderr, "in add_parameter");
#endif
    Data_Get_Struct(self, SAPNW_FUNC_DESC, dptr);

  /* register parameter definition */
  name = rb_iv_get(parameter, "@name");
  type = rb_iv_get(parameter, "@type");
  direction = rb_iv_get(parameter, "@direction");
  nucLength = rb_iv_get(parameter, "@len");
  ucLength = rb_iv_get(parameter, "@ulen");
  decimals = rb_iv_get(parameter, "@decimals");
#ifdef _WIN32
    fprintf(stderr, "Got parameter: %s\n", StringValueCStr(name));
    fprintf(stderr, "Got parameter: %s - type: %d\n", StringValueCStr(name), (int) NUM2INT(type));
#endif
    if (NUM2INT(type) == RFCTYPE_STRUCTURE ||
        NUM2INT(type) == RFCTYPE_TABLE) {
    ptypedef = rb_iv_get(parameter, "@typedef");
    type_name = rb_iv_get(ptypedef, "@name");
    fields = rb_iv_get(ptypedef, "@fields");
      type_desc = SAPNW_build_type(type_name, fields);
#ifdef _WIN32
    fprintf(stderr, "add_parameter: after build_type");
#endif
    parm_desc = SAPNW_alloc_parameter((pname = u8to16(name)), NUM2INT(type), NUM2INT(direction), 0, 0, 0, type_desc, NULL);
#ifdef _WIN32
    fprintf(stderr, "add_parameter: after alloc_parameter");
#endif
    } else {
    parm_desc = SAPNW_alloc_parameter((pname = u8to16(name)), NUM2INT(type), NUM2INT(direction), NUM2INT(nucLength), NUM2INT(ucLength), NUM2INT(decimals), NULL, NULL);
#ifdef _WIN32
    fprintf(stderr, "add_parameter: after alloc_parameter2");
#endif
    }
    free(pname);
  rc = RfcAddParameter(dptr->handle, parm_desc, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcAddParameter: "),
                                           name),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }
#ifdef _WIN32
  fprintf(stderr, "add_parameter: finished");
#endif

  return parameter;
}


static VALUE get_time_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_TIME timeBuff;
    VALUE val;

  rc = RfcGetTime(hcont, name, timeBuff, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetDate: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }
  val = u16to8c(timeBuff, 6);
    return val;
}


static VALUE get_date_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_DATE dateBuff;
    VALUE val;

  rc = RfcGetDate(hcont, name, dateBuff, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetDate: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }
  val = u16to8c(dateBuff, 8);
    return val;
}


static VALUE get_int_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_INT rfc_int;

  rc = RfcGetInt(hcont, name, &rfc_int, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetInt: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }
    return INT2NUM((int) rfc_int);
}


static VALUE get_int1_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_INT1 rfc_int1;

  rc = RfcGetInt1(hcont, name, &rfc_int1, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetInt1: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }
    return INT2NUM((int) rfc_int1);
}


static VALUE get_int2_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_INT2 rfc_int2;

  rc = RfcGetInt2(hcont, name, &rfc_int2, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetInt2: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }
    return INT2NUM((int) rfc_int2);
}


static VALUE get_float_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_FLOAT rfc_float;

  rc = RfcGetFloat(hcont, name, &rfc_float, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetFloat: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }
    return rb_float_new((double) rfc_float);
}


static VALUE get_string_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    VALUE val;
    unsigned strLen, retStrLen;
    char * buffer;

  rc = RfcGetStringLength(hcont, name, &strLen, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetStringLength: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

  /* bail out if string is empty */
  if (strLen == 0)
      return Qnil;

  buffer = make_space(strLen*4 + 2);
  rc = RfcGetString(hcont, name, (SAP_UC *)buffer, strLen + 2, &retStrLen, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetString: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

  //val = u16to8c((SAP_UC *)buffer, retStrLen*2);
  val = u16to8c((SAP_UC *)buffer, retStrLen);
    free(buffer);
    return val;
}


static VALUE get_xstring_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    VALUE val;
    unsigned strLen, retStrLen;
    char * buffer;

  rc = RfcGetStringLength(hcont, name, &strLen, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetStringLength in XSTRING: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

  /* bail out if string is empty */
  if (strLen == 0)
      return Qnil;

  buffer = make_space(strLen);
  rc = RfcGetXString(hcont, name, (SAP_RAW *)buffer, strLen, &retStrLen, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetXString: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

    val = rb_enc_str_new(buffer, strLen, rb_utf8_encoding());
    free(buffer);
    return val;
}



static VALUE get_num_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, unsigned ulen){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    char * buffer;
    VALUE val;

  buffer = make_space(ulen*2+1); /* seems that you need 2 null bytes to terminate a string ...*/
  rc = RfcGetNum(hcont, name, (RFC_NUM *)buffer, ulen, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetNum: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }
    val = u16to8((SAP_UC *)buffer);
  free(buffer);

    return val;
}


static VALUE get_bcd_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    VALUE val;
    unsigned strLen, retStrLen;
    char * buffer;

  /* select a random long length for a BCD */
  strLen = 100;

  buffer = make_space(strLen*2);
  rc = RfcGetString(hcont, name, (SAP_UC *)buffer, strLen, &retStrLen, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("(bcd)Problem with RfcGetString: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

  //val = u16to8c((SAP_UC *)buffer, retStrLen*2);
  val = u16to8c((SAP_UC *)buffer, retStrLen);
    free(buffer);
  return rb_funcall(val, rb_intern("to_f"), 0);
}


static VALUE get_char_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, unsigned ulen){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    char * buffer;
    VALUE val;

  buffer = make_space(ulen*4+2); /* seems that you need 2 null bytes to terminate a string ...*/

  rc = RfcGetChars(hcont, name, (RFC_CHAR *)buffer, ulen, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetChars: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }
    //fprintfU(stderr, cU("Return char: %s\n"), buffer);
    val = u16to8((SAP_UC *)buffer);
  free(buffer);

    return val;
}


static VALUE get_byte_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, unsigned len){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    char * buffer;
    VALUE val;

  buffer = make_space(len);
  rc = RfcGetBytes(hcont, name, (SAP_RAW *)buffer, len, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetBytes: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }
    val = rb_enc_str_new(buffer, len, rb_utf8_encoding());
  free(buffer);

    return val;
}


static VALUE get_structure_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_STRUCTURE_HANDLE line;
    RFC_TYPE_DESC_HANDLE typeHandle;
    RFC_FIELD_DESC fieldDesc;
    unsigned fieldCount, i;
    VALUE val;

  rc = RfcGetStructure(hcont, name, &line, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetStructure: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

    typeHandle = RfcDescribeType(line, &errorInfo);
  if (typeHandle == NULL) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcDescribeType: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

    rc = RfcGetFieldCount(typeHandle, &fieldCount, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetFieldCount: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

  val = rb_hash_new();
  for (i = 0; i < fieldCount; i++) {
      rc = RfcGetFieldDescByIndex(typeHandle, i, &fieldDesc, &errorInfo);
    if (rc != RFC_OK) {
         SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetFieldDescByIndex: "),
                                             u16to8(name)),
                           INT2NUM(errorInfo.code),
                                                  u16to8(errorInfo.key),
                                         u16to8(errorInfo.message));
    }

    /* process each field type ...*/
    rb_hash_aset(val, u16to8(fieldDesc.name), get_field_value(line, fieldDesc));
    }

    return val;
}


static VALUE get_field_value(DATA_CONTAINER_HANDLE hcont, RFC_FIELD_DESC fieldDesc){

  VALUE pvalue;
  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_TABLE_HANDLE tableHandle;

  pvalue = Qnil;
  switch (fieldDesc.type) {
    case RFCTYPE_DATE:
          pvalue = get_date_value(hcont, fieldDesc.name);
          break;
    case RFCTYPE_TIME:
          pvalue = get_time_value(hcont, fieldDesc.name);
          break;
    case RFCTYPE_NUM:
          pvalue = get_num_value(hcont, fieldDesc.name, fieldDesc.nucLength);
          break;
    case RFCTYPE_BCD:
          pvalue = get_bcd_value(hcont, fieldDesc.name);
          break;
    case RFCTYPE_CHAR:
          pvalue = get_char_value(hcont, fieldDesc.name, fieldDesc.nucLength);
          break;
    case RFCTYPE_BYTE:
          pvalue = get_byte_value(hcont, fieldDesc.name, fieldDesc.nucLength);
          break;
    case RFCTYPE_FLOAT:
          pvalue = get_float_value(hcont, fieldDesc.name);
          break;
    case RFCTYPE_INT:
          pvalue = get_int_value(hcont, fieldDesc.name);
          break;
    case RFCTYPE_INT2:
          pvalue = get_int2_value(hcont, fieldDesc.name);
          break;
    case RFCTYPE_INT1:
          pvalue = get_int1_value(hcont, fieldDesc.name);
          break;
    case RFCTYPE_STRUCTURE:
          pvalue = get_structure_value(hcont, fieldDesc.name);
          break;
    case RFCTYPE_TABLE:
      rc = RfcGetTable(hcont, fieldDesc.name, &tableHandle, &errorInfo);
      if (rc != RFC_OK) {
             SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem RfcGetTable (get_field): "),
                                           u16to8(fieldDesc.name)),
                              INT2NUM(errorInfo.code),
                                                  u16to8(errorInfo.key),
                                           u16to8(errorInfo.message));
         }
          pvalue = get_table_value(tableHandle, fieldDesc.name);
          break;
    case RFCTYPE_XMLDATA:
          fprintf(stderr, "shouldnt get a XMLDATA type parameter - abort\n");
            exit(1);
          break;
    case RFCTYPE_STRING:
          pvalue = get_string_value(hcont, fieldDesc.name);
          break;
    case RFCTYPE_XSTRING:
          pvalue = get_xstring_value(hcont, fieldDesc.name);
          break;
        default:
          fprintf(stderr, "This type is not implemented (%d) - abort\n", fieldDesc.type);
            exit(1);
          break;
  }

  return pvalue;
}


static VALUE get_table_line(RFC_STRUCTURE_HANDLE line){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_TYPE_DESC_HANDLE typeHandle;
    RFC_FIELD_DESC fieldDesc;
    unsigned fieldCount, i;
    VALUE val;

    typeHandle = RfcDescribeType(line, &errorInfo);
  if (typeHandle == NULL) {
       SAPNW_rfc_call_error(rb_str_new2("Problem with RfcDescribeType "),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

    rc = RfcGetFieldCount(typeHandle, &fieldCount, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_new2("Problem with RfcGetFieldCount "),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

  val = rb_hash_new();
  for (i = 0; i < fieldCount; i++) {
      rc = RfcGetFieldDescByIndex(typeHandle, i, &fieldDesc, &errorInfo);
    if (rc != RFC_OK) {
         SAPNW_rfc_call_error(rb_str_new2("Problem with RfcGetFieldDescByIndex: "),
                           INT2NUM(errorInfo.code),
                                                  u16to8(errorInfo.key),
                                         u16to8(errorInfo.message));
    }

    /* process each field type ...*/
    rb_hash_aset(val, u16to8(fieldDesc.name), get_field_value(line, fieldDesc));
    }

    return val;
}


static VALUE get_table_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    VALUE val;
    unsigned tabLen, r;
    RFC_STRUCTURE_HANDLE line;
    rc = RfcGetRowCount(hcont, &tabLen, NULL);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem RfcGetRowCount: "),
                                           u16to8(name)),
                            INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                              u16to8(errorInfo.message));
  }
    val = rb_ary_new();
  for (r = 0; r < tabLen; r++){
      RfcMoveTo(hcont, r, NULL);
      line = RfcGetCurrentRow(hcont, NULL);
        rb_ary_push(val, get_table_line(line));
    }

    return val;
}


static VALUE get_parameter_value(VALUE name, SAPNW_FUNC *fptr){

    //SAPNW_CONN_INFO *cptr;
    SAPNW_FUNC_DESC *dptr;
  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
  RFC_PARAMETER_DESC paramDesc;
    RFC_TABLE_HANDLE tableHandle;
    SAP_UC *p_name;
  VALUE pvalue;

    dptr = fptr->desc_handle;
    //cptr = dptr->conn_handle;

  /* get the parameter description */
  rc = RfcGetParameterDescByName(dptr->handle, (p_name = u8to16(name)), &paramDesc, &errorInfo);

  /* bail on a bad call for parameter description */
  if (rc != RFC_OK) {
      free(p_name);
        SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetParameterDescByName: "), name),
                             INT2NUM(errorInfo.code),
                                                 u16to8(errorInfo.key),
                                                 u16to8(errorInfo.message));
    }

  pvalue = Qnil;
  switch (paramDesc.type) {
    case RFCTYPE_DATE:
          pvalue = get_date_value(fptr->handle, p_name);
          break;
    case RFCTYPE_TIME:
          pvalue = get_time_value(fptr->handle, p_name);
          break;
    case RFCTYPE_NUM:
          pvalue = get_num_value(fptr->handle, p_name, paramDesc.nucLength);
          break;
    case RFCTYPE_BCD:
          pvalue = get_bcd_value(fptr->handle, p_name);
          break;
    case RFCTYPE_CHAR:
          pvalue = get_char_value(fptr->handle, p_name, paramDesc.nucLength);
          break;
    case RFCTYPE_BYTE:
          pvalue = get_byte_value(fptr->handle, p_name, paramDesc.nucLength);
          break;
    case RFCTYPE_FLOAT:
          pvalue = get_float_value(fptr->handle, p_name);
          break;
    case RFCTYPE_INT:
          pvalue = get_int_value(fptr->handle, p_name);
          break;
    case RFCTYPE_INT2:
          pvalue = get_int2_value(fptr->handle, p_name);
          break;
    case RFCTYPE_INT1:
          pvalue = get_int1_value(fptr->handle, p_name);
          break;
    case RFCTYPE_STRUCTURE:
          pvalue = get_structure_value(fptr->handle, p_name);
          break;
    case RFCTYPE_TABLE:
      rc = RfcGetTable(fptr->handle, p_name, &tableHandle, &errorInfo);
      if (rc != RFC_OK) {
             SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem RfcGetTable: "),
                                           u16to8(p_name)),
                              INT2NUM(errorInfo.code),
                                                  u16to8(errorInfo.key),
                                           u16to8(errorInfo.message));
         }
          //pvalue = get_table_value(fptr, fptr->handle, p_name);
          pvalue = get_table_value(tableHandle, p_name);
          break;
    case RFCTYPE_XMLDATA:
          fprintf(stderr, "shouldnt get a XMLDATA type parameter - abort\n");
            exit(1);
          break;
    case RFCTYPE_STRING:
          pvalue = get_string_value(fptr->handle, p_name);
          break;
    case RFCTYPE_XSTRING:
          pvalue = get_xstring_value(fptr->handle, p_name);
          break;
        default:
          fprintf(stderr, "This type is not implemented (%d) - abort\n", paramDesc.type);
            exit(1);
          break;
  }
    free(p_name);


  return pvalue;
}


void set_date_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    SAP_UC *p_value;
    RFC_DATE date_value;

    if (TYPE(value) != T_STRING)
        rb_raise(rb_eRuntimeError, "RfcSetDate invalid Input value type: %s\n", StringValueCStr(value));
    //if (RSTRING(value)->len != 8)
    if (RSTRING_LEN(value) != 8)
        rb_raise(rb_eRuntimeError, "RfcSetDate invalid date format: %s\n", StringValueCStr(value));
  p_value = u8to16(value);
    memcpy((char *)date_value+0, (char *)p_value, 16);
  free(p_value);

  rc = RfcSetDate(hcont, name, date_value, &errorInfo);
  if (rc != RFC_OK) {
      SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcSetDate: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                        u16to8(errorInfo.message));
  }

    return;
}


void set_time_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    SAP_UC *p_value;
    RFC_TIME time_value;

    if (TYPE(value) != T_STRING)
        rb_raise(rb_eRuntimeError, "RfcSetTime invalid Input value type: %s\n", StringValueCStr(value));
    //if (RSTRING(value)->len != 6)
    if (RSTRING_LEN(value) != 6)
        rb_raise(rb_eRuntimeError, "RfcSetTime invalid date format: %s\n", StringValueCStr(value));
  p_value = u8to16(value);
    memcpy((char *)time_value+0, (char *)p_value, 12);
  free(p_value);

  rc = RfcSetTime(hcont, name, time_value, &errorInfo);
  if (rc != RFC_OK) {
      SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcSetTime: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                        u16to8(errorInfo.message));
  }

    return;
}


void set_num_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value, unsigned max){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    SAP_UC *p_value;

    if (TYPE(value) != T_STRING)
        rb_raise(rb_eRuntimeError, "RfcSetNum invalid Input value type: %s\n", StringValueCStr(value));
    //if (RSTRING(value)->len > max)
    if (RSTRING_LEN(value) > max)
        rb_raise(rb_eRuntimeError, "RfcSetNum string too long: %s\n", StringValueCStr(value));

  p_value = u8to16(value);
  rc = RfcSetNum(hcont, name, (RFC_NUM *)p_value, strlenU(p_value), &errorInfo);
  free(p_value);
  if (rc != RFC_OK) {
      SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcSetNum: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                        u16to8(errorInfo.message));
  }

    return;
}


void set_bcd_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    VALUE val_to_s;
    SAP_UC *p_value;

  /* make sure that the BCD source value is a string */
  val_to_s = rb_funcall(value, rb_intern("to_s"), 0);
    if (TYPE(val_to_s) != T_STRING)
        rb_raise(rb_eRuntimeError, "(bcd)RfcSetString invalid Input value type: %s\n", StringValueCStr(val_to_s));

  p_value = u8to16(val_to_s);
  rc = RfcSetString(hcont, name, p_value, strlenU(p_value), &errorInfo);
  free(p_value);
  if (rc != RFC_OK) {
      SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("(bcd)Problem with RfcSetString: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                        u16to8(errorInfo.message));
  }

    return;
}


void set_char_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value, unsigned max){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    SAP_UC *p_value;

    if (TYPE(value) != T_STRING)
        rb_raise(rb_eRuntimeError, "RfcSetChar invalid Input value type: %s\n", StringValueCStr(value));

  p_value = u8to16(value);
  rc = RfcSetChars(hcont, name, p_value, strlenU(p_value), &errorInfo);
  free(p_value);
  if (rc != RFC_OK) {
      SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcSetChars: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                        u16to8(errorInfo.message));
  }

    return;
}


void set_byte_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value, unsigned max){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;

    if (TYPE(value) != T_STRING)
        rb_raise(rb_eRuntimeError, "RfcSetByte invalid Input value type: %s\n", StringValueCStr(value));
    //if (RSTRING(value)->len > max)
    if (RSTRING_LEN(value) > max)
        rb_raise(rb_eRuntimeError, "RfcSetByte string too long: %s\n", StringValueCStr(value));
  //rc = RfcSetBytes(hcont, name, (SAP_RAW *)StringValueCStr(value), RSTRING(value)->len, &errorInfo);
  rc = RfcSetBytes(hcont, name, (SAP_RAW *)StringValueCStr(value), RSTRING_LEN(value), &errorInfo);
  if (rc != RFC_OK) {
      SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcSetBytes: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                        u16to8(errorInfo.message));
  }

    return;
}


void set_float_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;

    if (TYPE(value) != T_FLOAT)
        rb_raise(rb_eRuntimeError, "RfcSetFloat invalid Input value type on: %s\n",
                 u16to8(name));
  rc = RfcSetFloat(hcont, name, (RFC_FLOAT) NUM2DBL(value), &errorInfo);
  if (rc != RFC_OK) {
      SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcSetFloat: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                        u16to8(errorInfo.message));
  }

    return;
}


void set_int_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;

    if (TYPE(value) != T_FIXNUM)
        rb_raise(rb_eRuntimeError, "RfcSetInt invalid Input value type on: %s\n",
                 u16to8(name));
  rc = RfcSetInt(hcont, name, (RFC_INT) NUM2INT(value), &errorInfo);
  if (rc != RFC_OK) {
      SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcSetInt: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                        u16to8(errorInfo.message));
  }

    return;
}


void set_int1_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;

    if (TYPE(value) != T_FIXNUM)
        rb_raise(rb_eRuntimeError, "RfcSetInt1 invalid Input value type on: %s\n",
                 u16to8(name));
    if (NUM2INT(value) > 255)
        rb_raise(rb_eRuntimeError, "RfcSetInt1 invalid Input value too big on: %s\n",
                 u16to8(name));
  rc = RfcSetInt1(hcont, name, (RFC_INT1) NUM2INT(value), &errorInfo);
  if (rc != RFC_OK) {
      SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcSetInt1: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                        u16to8(errorInfo.message));
  }

    return;
}


void set_int2_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;

    if (TYPE(value) != T_FIXNUM)
        rb_raise(rb_eRuntimeError, "RfcSetInt2 invalid Input value type on: %s\n",
                 u16to8(name));
    if (NUM2INT(value) > 4095)
        rb_raise(rb_eRuntimeError, "RfcSetInt1 invalid Input value too big on: %s\n",
                 u16to8(name));
  rc = RfcSetInt2(hcont, name, (RFC_INT2) NUM2INT(value), &errorInfo);
  if (rc != RFC_OK) {
      SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcSetInt2: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                        u16to8(errorInfo.message));
  }

    return;
}


void set_string_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    SAP_UC *p_value;

    if (TYPE(value) != T_STRING)
        rb_raise(rb_eRuntimeError, "RfcSetString invalid Input value type: %s\n", StringValueCStr(value));

  p_value = u8to16(value);
  rc = RfcSetString(hcont, name, p_value, strlenU(p_value), &errorInfo);
  free(p_value);
  if (rc != RFC_OK) {
      SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcSetString: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                        u16to8(errorInfo.message));
  }

    return;
}


void set_xstring_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;

    if (TYPE(value) != T_STRING)
        rb_raise(rb_eRuntimeError, "RfcSetXString invalid Input value type: %s\n", StringValueCStr(value));

  //rc = RfcSetXString(hcont, name, (SAP_RAW *)StringValueCStr(value), RSTRING(value)->len, &errorInfo);
  rc = RfcSetXString(hcont, name, (SAP_RAW *)StringValueCStr(value), RSTRING_LEN(value), &errorInfo);
  if (rc != RFC_OK) {
      SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcSetXString: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                        u16to8(errorInfo.message));
  }

    return;
}


void set_structure_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_STRUCTURE_HANDLE line;
    RFC_TYPE_DESC_HANDLE typeHandle;
    RFC_FIELD_DESC fieldDesc;
    SAP_UC *p_name;
    unsigned i;
    VALUE keys, key, val;

    if (TYPE(value) != T_HASH)
        rb_raise(rb_eRuntimeError, "RfcSetStructure invalid Input value type\n");


  keys = rb_funcall(value, rb_intern("keys"), 0);
    if (TYPE(keys) != T_ARRAY)
        rb_raise(rb_eRuntimeError, "in RfcSetStructure something went wrong with hash-keys\n");

  rc = RfcGetStructure(hcont, name, &line, &errorInfo);
  if (rc != RFC_OK) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("(set)Problem with RfcGetStructure: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

    typeHandle = RfcDescribeType(line, &errorInfo);
  if (typeHandle == NULL) {
       SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("(set)Problem with RfcDescribeType: "),
                                           u16to8(name)),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

    //for (i = 0; i < RARRAY(keys)->len; i++) {
    for (i = 0; i < RARRAY_LEN(keys); i++) {
    key = rb_ary_entry(keys, i);
    val = rb_hash_aref(value, key);

      rc = RfcGetFieldDescByName(typeHandle, (p_name = u8to16(key)), &fieldDesc, &errorInfo);
    if (rc != RFC_OK) {
         SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem with RfcGetFieldDescByName: "),
                                             u16to8(name)),
                           INT2NUM(errorInfo.code),
                                                  u16to8(errorInfo.key),
                                         u16to8(errorInfo.message));
    }

    memcpy(fieldDesc.name, p_name, strlenU(p_name)*2+2);
        free(p_name);
    set_field_value(line, fieldDesc, val);
    }

    return;
}


void set_field_value(DATA_CONTAINER_HANDLE hcont, RFC_FIELD_DESC fieldDesc, VALUE value){
  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_TABLE_HANDLE tableHandle;

  switch (fieldDesc.type) {
    case RFCTYPE_DATE:
          set_date_value(hcont, fieldDesc.name, value);
          break;
    case RFCTYPE_TIME:
          set_time_value(hcont, fieldDesc.name, value);
          break;
    case RFCTYPE_NUM:
          set_num_value(hcont, fieldDesc.name, value, fieldDesc.nucLength);
          break;
    case RFCTYPE_BCD:
          set_bcd_value(hcont, fieldDesc.name, value);
          break;
    case RFCTYPE_CHAR:
          set_char_value(hcont, fieldDesc.name, value, fieldDesc.nucLength);
          break;
    case RFCTYPE_BYTE:
          set_byte_value(hcont, fieldDesc.name, value, fieldDesc.nucLength);
          break;
    case RFCTYPE_FLOAT:
          set_float_value(hcont, fieldDesc.name, value);
          break;
    case RFCTYPE_INT:
          set_int_value(hcont, fieldDesc.name, value);
          break;
    case RFCTYPE_INT2:
          set_int2_value(hcont, fieldDesc.name, value);
          break;
    case RFCTYPE_INT1:
          set_int1_value(hcont, fieldDesc.name, value);
          break;
    case RFCTYPE_STRUCTURE:
          set_structure_value(hcont, fieldDesc.name, value);
          break;
    case RFCTYPE_TABLE:
      rc = RfcGetTable(hcont, fieldDesc.name, &tableHandle, &errorInfo);
      if (rc != RFC_OK) {
          SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("(set parameter)Problem RfcGetTable: "),
                                           u16to8(fieldDesc.name)),
                            INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                              u16to8(errorInfo.message));
      }
          set_table_value(tableHandle, fieldDesc.name, value);
          break;
    case RFCTYPE_XMLDATA:
          fprintf(stderr, "shouldnt get a XMLDATA type parameter - abort\n");
            exit(1);
          break;
    case RFCTYPE_STRING:
          set_string_value(hcont, fieldDesc.name, value);
          break;
    case RFCTYPE_XSTRING:
          set_xstring_value(hcont, fieldDesc.name, value);
          break;
        default:
          fprintf(stderr, "Set field - This type is not implemented (%d) - abort\n", fieldDesc.type);
            exit(1);
          break;
  }

  return;
}


void set_table_line(RFC_STRUCTURE_HANDLE line, VALUE value){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_TYPE_DESC_HANDLE typeHandle;
    RFC_FIELD_DESC fieldDesc;
    unsigned i;
    SAP_UC * p_name;
    VALUE keys, key, val;

    if (TYPE(value) != T_HASH)
        rb_raise(rb_eRuntimeError, "set_table_line invalid Input value type\n");


  keys = rb_funcall(value, rb_intern("keys"), 0);
    if (TYPE(keys) != T_ARRAY)
        rb_raise(rb_eRuntimeError, "in set_table_line something went wrong with hash-keys\n");


    typeHandle = RfcDescribeType(line, &errorInfo);
  if (typeHandle == NULL) {
       SAPNW_rfc_call_error(rb_str_new2("(set_table_line)Problem with RfcDescribeType"),
                         INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                       u16to8(errorInfo.message));
  }

    //for (i = 0; i < RARRAY(keys)->len; i++) {
    for (i = 0; i < RARRAY_LEN(keys); i++) {
    key = rb_ary_entry(keys, i);
    val = rb_hash_aref(value, key);

      rc = RfcGetFieldDescByName(typeHandle, (p_name = u8to16(key)), &fieldDesc, &errorInfo);
    if (rc != RFC_OK) {
         SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("(set_table_line)Problem with RfcGetFieldDescByName: "), key),
                           INT2NUM(errorInfo.code),
                                                  u16to8(errorInfo.key),
                                         u16to8(errorInfo.message));
    }

    memcpy(fieldDesc.name, p_name, strlenU(p_name)*2+2);
        free(p_name);
    set_field_value(line, fieldDesc, val);

    }

    return;
}


void set_table_value(DATA_CONTAINER_HANDLE hcont, SAP_UC *name, VALUE value){

  RFC_ERROR_INFO errorInfo;
    RFC_STRUCTURE_HANDLE line;
    unsigned r;
    VALUE row;

  Check_Type(value, T_ARRAY);
    //for (r = 0; r < RARRAY(value)->len; r++) {
    for (r = 0; r < RARRAY_LEN(value); r++) {
    row = rb_ary_entry(value, r);
      line = RfcAppendNewRow(hcont, &errorInfo);
    if (line == NULL) {
           SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem RfcAppendNewRow: "),
                                           u16to8(name)),
                                INT2NUM(errorInfo.code),
                                                    u16to8(errorInfo.key),
                                              u16to8(errorInfo.message));
    }
        set_table_line(line, row);
    }

    return;
}


void set_parameter_value(SAPNW_FUNC *fptr, VALUE name, VALUE value){

    SAPNW_CONN_INFO *cptr;
    SAPNW_FUNC_DESC *dptr;
  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
  RFC_PARAMETER_DESC paramDesc;
    RFC_TABLE_HANDLE tableHandle;
    SAP_UC *p_name;

  if (value == Qnil)
      return;

    dptr = fptr->desc_handle;
    cptr = dptr->conn_handle;

  /* get the parameter description */
  rc = RfcGetParameterDescByName(dptr->handle, (p_name = u8to16(name)), &paramDesc, &errorInfo);

  /* bail on a bad call for parameter description */
  if (rc != RFC_OK) {
      free(p_name);
        SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("(Set)Problem with RfcGetParameterDescByName: "), name),
                             INT2NUM(errorInfo.code),
                                                 u16to8(errorInfo.key),
                                                 u16to8(errorInfo.message));
    }

  switch (paramDesc.type) {
    case RFCTYPE_DATE:
          set_date_value(fptr->handle, p_name, value);
          break;
    case RFCTYPE_TIME:
          set_time_value(fptr->handle, p_name, value);
          break;
    case RFCTYPE_NUM:
          set_num_value(fptr->handle, p_name, value, paramDesc.nucLength);
          break;
    case RFCTYPE_BCD:
          set_bcd_value(fptr->handle, p_name, value);
          break;
    case RFCTYPE_CHAR:
          set_char_value(fptr->handle, p_name, value, paramDesc.nucLength);
          break;
    case RFCTYPE_BYTE:
          set_byte_value(fptr->handle, p_name, value, paramDesc.nucLength);
          break;
    case RFCTYPE_FLOAT:
          set_float_value(fptr->handle, p_name, value);
          break;
    case RFCTYPE_INT:
          set_int_value(fptr->handle, p_name, value);
          break;
    case RFCTYPE_INT2:
          set_int2_value(fptr->handle, p_name, value);
          break;
    case RFCTYPE_INT1:
          set_int1_value(fptr->handle, p_name, value);
          break;
    case RFCTYPE_STRUCTURE:
          set_structure_value(fptr->handle, p_name, value);
          break;
    case RFCTYPE_TABLE:
      rc = RfcGetTable(fptr->handle, p_name, &tableHandle, &errorInfo);
      if (rc != RFC_OK) {
          SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("(set parameter)Problem RfcGetTable: "),
                                           u16to8(p_name)),
                            INT2NUM(errorInfo.code),
                                                u16to8(errorInfo.key),
                                              u16to8(errorInfo.message));
      }
          set_table_value(tableHandle, p_name, value);
          break;
    case RFCTYPE_XMLDATA:
          fprintf(stderr, "shouldnt get a XMLDATA type parameter - abort\n");
            exit(1);
          break;
    case RFCTYPE_STRING:
          set_string_value(fptr->handle, p_name, value);
          break;
    case RFCTYPE_XSTRING:
          set_xstring_value(fptr->handle, p_name, value);
          break;
        default:
          fprintf(stderr, "This type is not implemented (%d) - abort\n", paramDesc.type);
            exit(1);
          break;
  }
    free(p_name);

  return;
}


RFC_RC SAP_API SAPNW_function_callback(RFC_CONNECTION_HANDLE rfcHandle, RFC_FUNCTION_HANDLE funcHandle, RFC_ERROR_INFO* errorInfoP){

  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    RFC_FUNCTION_DESC_HANDLE func_desc_handle;
    RFC_ABAP_NAME func_name;
    SAPNW_FUNC_DESC *dptr;
    SAPNW_FUNC *fptr;
    VALUE parameters, function, fcall, parm, name, value, row, result, error, ecode, ekey, emessage;
    SAP_UC *p_name;
    SAP_UC *pkey;
    SAP_UC *pmessage;
    SAP_UC *useless_void;
    int i, r;
    unsigned tabLen;
    RFC_TABLE_HANDLE tableHandle;
    RFC_STRUCTURE_HANDLE line;

  /* find out what Function Call this is */
    func_desc_handle = RfcDescribeFunction(funcHandle, &errorInfo);
  if (func_desc_handle == NULL) {
      SAPNW_rfc_serv_error(rb_str_new2("Problem in RfcDescribeFunction: "),
                           INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                               u16to8(errorInfo.message));
    }
    dptr = ALLOC(SAPNW_FUNC_DESC);
    dptr->handle = func_desc_handle;
    dptr->conn_handle = NULL;

    rc = RfcGetFunctionName(dptr->handle, func_name, &errorInfo);
  if (rc != RFC_OK) {
      SAPNW_rfc_serv_error(rb_str_concat(rb_str_new2("Problem in RfcGetFunctionName: "), u16to8(func_name)),
                           INT2NUM(errorInfo.code),
                                               u16to8(errorInfo.key),
                                               u16to8(errorInfo.message));
    }

    /* create a function call container to pass into the all back */
  function = rb_hash_aref(global_server_functions, u16to8(func_name));
    if (function == Qnil) {
       /* we dont know this function - so error */
     dptr->handle = NULL;
     free(dptr);
         return RFC_NOT_FOUND;
    }

    fptr = ALLOC(SAPNW_FUNC);
    fptr->handle = funcHandle;
    fptr->desc_handle = dptr;

    /* XXX must test that we got one */
  fcall = rb_funcall(function, rb_intern("make_empty_function_call"), 0);
  rb_iv_set(fcall, "@name", u16to8(func_name));


    /* unpick all the parameters ready for Ruby callback */
  parameters = rb_iv_get(fcall, "@parameters_list");
  Check_Type(parameters, T_ARRAY);
    //for (i = 0; i < RARRAY(parameters)->len; i++) {
    for (i = 0; i < RARRAY_LEN(parameters); i++) {
     parm = rb_ary_entry(parameters, i);
         name = rb_iv_get(parm, "@name");
       switch(NUM2INT(rb_iv_get(parm, "@direction"))) {
          case RFC_IMPORT:
               break;
          case RFC_EXPORT:
          case RFC_CHANGING:
                 value = get_parameter_value(name, fptr);
               rb_iv_set(parm, "@value", value);
               break;
          case RFC_TABLES:
         rc = RfcGetTable(fptr->handle, (p_name = u8to16(name)), &tableHandle, &errorInfo);
         if (rc != RFC_OK) {
            fptr->desc_handle = NULL;
             fptr->handle = NULL;
             free(fptr);
               SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem RfcGetTable: "), name),
                                    INT2NUM(errorInfo.code),
                                                        u16to8(errorInfo.key),
                                                        u16to8(errorInfo.message));
            }
                 rc = RfcGetRowCount(tableHandle, &tabLen, NULL);
         if (rc != RFC_OK) {
            fptr->desc_handle = NULL;
             fptr->handle = NULL;
             free(fptr);
               SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem RfcGetRowCount: "), name),
                                    INT2NUM(errorInfo.code),
                                                        u16to8(errorInfo.key),
                                                        u16to8(errorInfo.message));
            }
                 value = rb_ary_new();
         for (r = 0; r < tabLen; r++){
             RfcMoveTo(tableHandle, r, NULL);
                 line = RfcGetCurrentRow(tableHandle, NULL);
                     rb_ary_push(value, get_table_line(line));
                 }
                 free(p_name);
               rb_iv_set(parm, "@value", value);
               break;
         }
  }

  /* do Ruby callback */
     result = rb_funcall(function, rb_intern("handler"), 1, fcall);
     if (result == Qnil || result == Qfalse) {
       /* the callback has asked for termination */
     dptr->handle = NULL;
     free(dptr);
         return RFC_CLOSED;
     } else if (rb_intern(rb_class2name(rb_class_of(result))) == rb_intern("SAPNW::RFC::ServerException")) {
       /* check for an error thrown - pass it on to RFC stack ... */
     error = rb_iv_get(result, "@error");
     Check_Type(error, T_HASH);
     ecode = rb_hash_aref(error, rb_str_new2("code"));
     ekey = rb_hash_aref(error, rb_str_new2("key"));
     emessage = rb_hash_aref(error, rb_str_new2("message"));
     errorInfoP->code = RFC_ABAP_EXCEPTION;
     errorInfoP->group = NUM2INT(ecode);
     pkey = u8to16(ekey);
     useless_void = memcpyU(errorInfoP->key, pkey, (size_t)strlenU(pkey));
     free(pkey);
     pmessage = u8to16(emessage);
     useless_void = memcpyU(errorInfoP->message, pmessage, (size_t)strlenU(pmessage));
     free(pmessage);
         return RFC_ABAP_EXCEPTION;
     }

    /* repack all the parameters */
    //for (i = 0; i < RARRAY(parameters)->len; i++) {
    for (i = 0; i < RARRAY_LEN(parameters); i++) {
     parm = rb_ary_entry(parameters, i);
         name = rb_iv_get(parm, "@name");
       switch(NUM2INT(rb_iv_get(parm, "@direction"))) {
          case RFC_EXPORT:
               break;
          case RFC_IMPORT:
             case RFC_CHANGING:
               value = rb_iv_get(parm, "@value");
                 set_parameter_value(fptr, name, value);
               break;
          case RFC_TABLES:
               value = rb_iv_get(parm, "@value");
                 if (value == Qnil)
                   continue;
         Check_Type(value, T_ARRAY);
         rc = RfcGetTable(fptr->handle, (p_name = u8to16(name)), &tableHandle, &errorInfo);
         if (rc != RFC_OK) {
            fptr->desc_handle = NULL;
             fptr->handle = NULL;
             free(fptr);
               SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("(set)Problem RfcGetTable: "), name),
                                    INT2NUM(errorInfo.code),
                                                        u16to8(errorInfo.key),
                                                        u16to8(errorInfo.message));
            }
           //for (r = 0; r < RARRAY(value)->len; r++) {
           for (r = 0; r < RARRAY_LEN(value); r++) {
           row = rb_ary_entry(value, r);
                     line = RfcAppendNewRow(tableHandle, &errorInfo);
           if (line == NULL) {
               fptr->desc_handle = NULL;
                fptr->handle = NULL;
                free(fptr);
                  SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem RfcAppendNewRow: "), name),
                                       INT2NUM(errorInfo.code),
                                                            u16to8(errorInfo.key),
                                                        u16to8(errorInfo.message));
              }
                     set_table_line(line, row);
                 }

                 free(p_name);
               break;
          default:
                fprintf(stderr, "should get here!\n");
                    exit(1);
               break;
         }
  }

    /* send it home */
    fptr->desc_handle = NULL;
    fptr->handle = NULL;
    free(fptr);
  return RFC_OK;
}


/* install a RFC Server function */
static VALUE SAPNW_RFC_FUNCDESC_install(VALUE self, VALUE sysid){

  RFC_RC rc = RFC_OK;
    SAPNW_FUNC_DESC *dptr;
  RFC_ERROR_INFO errorInfo;
    SAP_UC * psysid;

    Data_Get_Struct(self, SAPNW_FUNC_DESC, dptr);

    rc = RfcInstallServerFunction((psysid = u8to16(sysid)), dptr->handle, SAPNW_function_callback, &errorInfo);
    free(psysid);

  /* bail on a bad lookup */
  if (rc != RFC_OK) {
        SAPNW_rfc_serv_error(rb_str_concat(rb_str_new2("Problem with RfcInstallServerFunction: "),
                                           rb_enc_str_new(dptr->name,strlen(dptr->name),dptr->name_enc)),

                             INT2NUM(errorInfo.code),
                                                 u16to8(errorInfo.key),
                                                 u16to8(errorInfo.message));
    }

  /* store a global pointer the the func desc for the function call back */
  rb_hash_aset(global_server_functions
              ,rb_enc_str_new(dptr->name,strlen(dptr->name),dptr->name_enc)
              ,self);

  return Qtrue;
}


/* Create a Function Module handle to be used for an RFC call */
static VALUE SAPNW_RFC_FUNC_CALL_set_active(VALUE self, VALUE name, VALUE active){

    SAPNW_CONN_INFO *cptr;
    SAPNW_FUNC_DESC *dptr;
    SAPNW_FUNC *fptr;
  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    SAP_UC *p_name;

    Data_Get_Struct(self, SAPNW_FUNC, fptr);
    dptr = fptr->desc_handle;
    cptr = dptr->conn_handle;

  rc = RfcSetParameterActive(fptr->handle, (p_name = u8to16(name)), NUM2INT(active), &errorInfo);
    free(p_name);
  if (rc != RFC_OK) {
         SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem RfcSetParameterActive: "), name),
                              INT2NUM(errorInfo.code),
                                                  u16to8(errorInfo.key),
                                           u16to8(errorInfo.message));
  }

    return Qtrue;
}



/* Create a Function Module handle to be used for an RFC call */
static VALUE SAPNW_RFC_FUNC_CALL_invoke(VALUE self){

    SAPNW_CONN_INFO *cptr;
    SAPNW_FUNC_DESC *dptr;
    SAPNW_FUNC *fptr;
  RFC_RC rc = RFC_OK;
  RFC_ERROR_INFO errorInfo;
    //RFC_ABAP_ERROR_INFO abapException;
    RFC_TABLE_HANDLE tableHandle;
    VALUE parameters, parm, name, value, row;
    SAP_UC *p_name;
    int i, r;
    unsigned tabLen;
    RFC_STRUCTURE_HANDLE line;


    Data_Get_Struct(self, SAPNW_FUNC, fptr);
    dptr = fptr->desc_handle;
    cptr = dptr->conn_handle;

    /* loop through all Input/Changing/tables parameters and set the values in the call */
  parameters = rb_iv_get(self, "@parameters_list");
  Check_Type(parameters, T_ARRAY);

    //for (i = 0; i < RARRAY(parameters)->len; i++) {
    for (i = 0; i < RARRAY_LEN(parameters); i++) {
     parm = rb_ary_entry(parameters, i);
         name = rb_iv_get(parm, "@name");
       switch(NUM2INT(rb_iv_get(parm, "@direction"))) {
          case RFC_EXPORT:
               break;
          case RFC_IMPORT:
             case RFC_CHANGING:
               value = rb_iv_get(parm, "@value");
                 set_parameter_value(fptr, name, value);
               break;
          case RFC_TABLES:
               value = rb_iv_get(parm, "@value");
                 if (value == Qnil)
                   continue;
         Check_Type(value, T_ARRAY);
         rc = RfcGetTable(fptr->handle, (p_name = u8to16(name)), &tableHandle, &errorInfo);
         if (rc != RFC_OK) {
               SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("(set)Problem RfcGetTable: "), name),
                                    INT2NUM(errorInfo.code),
                                                        u16to8(errorInfo.key),
                                                        u16to8(errorInfo.message));
            }
           //for (r = 0; r < RARRAY(value)->len; r++) {
           for (r = 0; r < RARRAY_LEN(value); r++) {
           row = rb_ary_entry(value, r);
                     line = RfcAppendNewRow(tableHandle, &errorInfo);
           if (line == NULL) {
                 SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem RfcAppendNewRow: "), name),
                                      INT2NUM(errorInfo.code),
                                                          u16to8(errorInfo.key),
                                                          u16to8(errorInfo.message));
              }
                     set_table_line(line, row);
                 }

                 free(p_name);
               break;
          default:
                fprintf(stderr, "should NOT get here!\n");
                    exit(1);
               break;
         }
  }

    //rc = RfcInvoke(cptr->handle, fptr->handle, &abapException, &errorInfo);
    rc = RfcInvoke(cptr->handle, fptr->handle, &errorInfo);

  /* bail on a bad RFC Call */
  if (rc != RFC_OK) {
        SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem Invoking RFC: ")
                                          ,rb_enc_str_new(dptr->name,strlen(dptr->name),dptr->name_enc))
                            ,INT2NUM(errorInfo.code)
                            ,u16to8(errorInfo.key)
                            ,u16to8(errorInfo.message));
    }

    //for (i = 0; i < RARRAY(parameters)->len; i++) {
    for (i = 0; i < RARRAY_LEN(parameters); i++) {
     parm = rb_ary_entry(parameters, i);
         name = rb_iv_get(parm, "@name");
       switch(NUM2INT(rb_iv_get(parm, "@direction"))) {
          case RFC_IMPORT:
               break;
          case RFC_EXPORT:
          case RFC_CHANGING:
                 value = get_parameter_value(name, fptr);
               rb_iv_set(parm, "@value", value);
               break;
          case RFC_TABLES:
         rc = RfcGetTable(fptr->handle, (p_name = u8to16(name)), &tableHandle, &errorInfo);
         if (rc != RFC_OK) {
               SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem RfcGetTable: "), name),
                                    INT2NUM(errorInfo.code),
                                                        u16to8(errorInfo.key),
                                                        u16to8(errorInfo.message));
            }
                 rc = RfcGetRowCount(tableHandle, &tabLen, NULL);
         if (rc != RFC_OK) {
               SAPNW_rfc_call_error(rb_str_concat(rb_str_new2("Problem RfcGetRowCount: "), name),
                                    INT2NUM(errorInfo.code),
                                                        u16to8(errorInfo.key),
                                                        u16to8(errorInfo.message));
            }
                 value = rb_ary_new();
         for (r = 0; r < tabLen; r++){
             RfcMoveTo(tableHandle, r, NULL);
                 line = RfcGetCurrentRow(tableHandle, NULL);
                     rb_ary_push(value, get_table_line(line));
                 }
                 free(p_name);
               rb_iv_set(parm, "@value", value);
               break;
         }
  }

  return Qtrue;
}



static VALUE error_error(VALUE obj)
{
    return rb_iv_get(obj, "@error");
}


static VALUE sapnwrfc_lib_version(VALUE class)
{
    char * ver;
    int len;
    unsigned majorVersion, minorVersion, patchLevel;
    VALUE ret;

    ver = make_space(100);

    RfcGetVersion(&majorVersion, &minorVersion, &patchLevel);

    len = sprintf(ver, "major: %d minor: %d patch: %d",
                  majorVersion, minorVersion, patchLevel);
    ret = rb_enc_str_new(ver, len, rb_utf8_encoding());
    free(ver);
    return(ret);
}



/* create a module init function */
void
Init_nwsaprfc(void) {

        /* create global for server functions map */
        global_server_functions = rb_hash_new();
        rb_global_variable(&global_server_functions);

        /* create the new module */
        mSAPNW = rb_define_module("SAPNW");
        mSAPNW_RFC = rb_define_module_under(mSAPNW, "RFC");
        rb_define_singleton_method(mSAPNW_RFC, "LibVersion", sapnwrfc_lib_version, 0);
        cSAPNW_RFC_HANDLE = rb_define_class_under(mSAPNW_RFC, "Handle", rb_cObject);
        cSAPNW_RFC_SERVERHANDLE = rb_define_class_under(mSAPNW_RFC, "ServerHandle", rb_cObject);
        cSAPNW_RFC_FUNCDESC = rb_define_class_under(mSAPNW_RFC, "FunctionDescriptor", rb_cObject);
        cSAPNW_RFC_FUNC_CALL = rb_define_class_under(mSAPNW_RFC, "FunctionCall", rb_cObject);
        cSAPNW_RFC_CONNEXCPT = rb_define_class_under(mSAPNW_RFC, "ConnectionException", rb_eException);
        cSAPNW_RFC_SERVEXCPT = rb_define_class_under(mSAPNW_RFC, "ServerException", rb_eException);
        cSAPNW_RFC_FUNCEXCPT = rb_define_class_under(mSAPNW_RFC, "FunctionCallException", rb_eException);
        rb_define_method(cSAPNW_RFC_CONNEXCPT, "error", error_error, 0);
        rb_define_method(cSAPNW_RFC_SERVEXCPT, "error", error_error, 0);
        rb_define_method(cSAPNW_RFC_FUNCEXCPT, "error", error_error, 0);

        /* define Handle methods */
        rb_define_singleton_method(cSAPNW_RFC_HANDLE, "new", SAPNW_RFC_HANDLE_new, 1);
        rb_define_method(cSAPNW_RFC_HANDLE, "connection_attributes", SAPNW_RFC_HANDLE_connection_attributes, 0);
        rb_define_method(cSAPNW_RFC_HANDLE, "reset_server_context", SAPNW_RFC_HANDLE_reset_server_context, 0);
        rb_define_method(cSAPNW_RFC_HANDLE, "function_lookup", SAPNW_RFC_HANDLE_function_lookup, 3);
        rb_define_method(cSAPNW_RFC_HANDLE, "close", SAPNW_RFC_HANDLE_close, 0);
        rb_define_method(cSAPNW_RFC_HANDLE, "ping", SAPNW_RFC_HANDLE_ping, 0);

        /* define ServerHandle methods */
        rb_define_singleton_method(cSAPNW_RFC_SERVERHANDLE, "new", SAPNW_RFC_SERVERHANDLE_new, 1);
        rb_define_method(cSAPNW_RFC_SERVERHANDLE, "connection_attributes", SAPNW_RFC_SERVERHANDLE_connection_attributes, 0);
        rb_define_method(cSAPNW_RFC_SERVERHANDLE, "accept_loop", SAPNW_RFC_SERVERHANDLE_accept, 2);
        rb_define_method(cSAPNW_RFC_SERVERHANDLE, "process_loop", SAPNW_RFC_SERVERHANDLE_process, 1);
        rb_define_method(cSAPNW_RFC_SERVERHANDLE, "close", SAPNW_RFC_SERVERHANDLE_close, 0);

        /* define FunctionDescription methods */
        rb_define_singleton_method(cSAPNW_RFC_FUNCDESC, "new", SAPNW_RFC_FUNCDESC_new, 1);
        rb_define_method(cSAPNW_RFC_FUNCDESC, "add_parameter", SAPNW_RFC_FUNCDESC_add_parameter, 1);
        rb_define_method(cSAPNW_RFC_FUNCDESC, "enable_XML", SAPNW_RFC_FUNCDESC_enable_XML, 0);
        rb_define_method(cSAPNW_RFC_FUNCDESC, "create_function_call", SAPNW_RFC_FUNCDESC_create_function_call, 1);
        rb_define_method(cSAPNW_RFC_FUNCDESC, "install", SAPNW_RFC_FUNCDESC_install, 1);

        /* define FunctionCall methods */
        rb_define_method(cSAPNW_RFC_FUNC_CALL, "invoke", SAPNW_RFC_FUNC_CALL_invoke, 0);
        rb_define_method(cSAPNW_RFC_FUNC_CALL, "set_active", SAPNW_RFC_FUNC_CALL_set_active, 2);
}

