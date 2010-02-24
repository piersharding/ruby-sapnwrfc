require 'mkmf'
require "rbconfig.rb"


if /yes/i.match(arg_config("--embed-vcruntime", "no"))
  print "invoking embed-vcruntime ...\n"
  print "Current CFLAGS: #{$CFLAGS}\n"
  $CFLAGS.gsub!(/(^.*[-\/])MD(\b.*$)/, '\1MT\2')
  print "Modified CFLAGS: #{$CFLAGS}\n"
end


rfclib = "sapnwrfc"

if ! /(mswin32|mingw32)/.match(Config::CONFIG["host_os"])
#  $CFLAGS += " -g -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -m64 -mno-3dnow -fno-strict-aliasing -pipe -fexceptions -funsigned-char -Wall -Wno-uninitialized -Wno-long-long -Wcast-align "
  $CFLAGS += " -D_LARGEFILE_SOURCE -mno-3dnow -fno-strict-aliasing -pipe -fexceptions -funsigned-char -Wall -Wno-uninitialized -Wno-long-long -Wcast-align "
  $CFLAGS += " -DSAPwithUNICODE "
  $CFLAGS += " -DSAPonUNIX "
#  $CFLAGS += " -DSAP_PLATFORM_MAKENAME=linuxx86_64 "
  $CFLAGS += " -D__NO_MATH_INLINES -fPIC "
  $CFLAGS += " -DSAPwithTHREADS "
else
  $CFLAGS += " -DWIN32"
#  $CFLAGS += " -D_DEBUG"
  $CFLAGS += " -D_CONSOLE"
  $CFLAGS += " -DUNICODE"
  $CFLAGS += " -D_UNICODE"
  $CFLAGS += " -DSAPwithUNICODE "
  $CFLAGS += " -DSAPonNT "
  $CFLAGS += " -DSAP_PLATFORM_MAKENAME=ntintel "
end
print "Modified CFLAGS: #{$CFLAGS}\n"

# if the rfcsdk is in /usr/sap/rfcsdk/[include|lib] then
# do ruby extconf.rb --with-nwrfcsdk-dir=/usr/sap/rfcsdk
dir_config("nwrfcsdk")

print "Modified CFLAGS: #{$CFLAGS}\n"
print "Modified CPPFLAGS: #{$CPPFLAGS}\n"
print "Modified LDFLAGS: #{$LDFLAGS}\n"
print "Modified LIBPATH: #{$LIBPATH}\n"

if (! have_header("sapnwrfc.h") )
  print "adding default nwrfcsdk location for headers ...\n"
  $CFLAGS += " -I/usr/sap/nwrfcsdk/include" 
  if (! have_header("sapnwrfc.h") )
	  print "This will not work - ABORTING because cannot find sapnwrfc.h\n"
		exit!
	end
end
  
#have_library("c")
have_library("m")
have_library("dl")
have_library("rt")
have_library("pthread")
#have_library("stdc++")

#$LDFLAGS += "-g -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -m64 -mno-3dnow -fno-strict-aliasing -pipe -fexceptions -funsigned-char -Wall -Wno-uninitialized -Wno-long-long -Wcast-align -DSAPonUNIX -DSAP_PLATFORM_MAKENAME=linuxx86_64 -DSAPwithUNICODE -D__NO_MATH_INLINES -pthread -fPIC -DSAPwithTHREADS ./lib/libdecnumber.so -ldl -pthread -lrt ./lib/libsapnwrfc.so"
#$LDFLAGS += "-g -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -m64 -mno-3dnow -fno-strict-aliasing -pipe -fexceptions -funsigned-char -Wall -Wno-uninitialized -Wno-long-long -Wcast-align -DSAPonUNIX -DSAP_PLATFORM_MAKENAME=linuxx86_64 -DSAPwithUNICODE -D__NO_MATH_INLINES -pthread -fPIC -DSAPwithTHREADS /home/piers/code/ruby/sapnw/lib/libdecnumber.so -ldl -pthread -lrt /home/piers/code/ruby/sapnw/lib/libsapnwrfc.so"

if (! have_library(rfclib) )
    print "searching for library sapnwrfc failed - checking default ...\n"
    $LDFLAGS += " -L/usr/sap/nwrfcsdk/lib -lsapnwrfc"
    $LDFLAGS += " -lsapnwrfc"
    if (! have_library(rfclib) )
	    print "This will not work - ABORTING because cannot find libsapnwrfc.so\n"
		  exit!
		end
end

if (! have_library("sapucum") )
    print "searching for library sapnwrfc failed - checking default ...\n"
    $LDFLAGS += " -L/usr/sap/nwrfcsdk/lib -lsapucum"
    $LDFLAGS += " -lsapucum"
    if (! have_library("sapucum") )
	    print "This will not work - ABORTING because cannot find libsapucum.so\n"
		  exit!
		end
end

#if (! have_library("sapu16_mt") )
#  print "DID NOT find libsapu16_mt - this may cause problems  ...\n"
#end

#if (! have_library("sapucum") )
#  if (! have_library("libsapucum") )
#    print "DID NOT find libsapucum - this may cause problems  ...\n"
#  end
#end

#if (! have_library("icudecnumber") )
#  print "DID NOT find libicudecnumber - this may cause problems  ...\n"
#end

if ! /(mswin32|mingw32)/.match(Config::CONFIG["host_os"])
  print "Existing Compile protocol: #{COMPILE_C} ...\n"
  COMPILE_C  =
    '$(CC) $(INCFLAGS) $(CFLAGS) $(CPPFLAGS) -E -c $< > $<.ii' + "\n\t" +
	  'perl ../../tools/u16lit.pl -le  $<.ii' + "\n\t" +
	  '$(CC) $(INCFLAGS) $(CFLAGS) $(CPPFLAGS) -c $<.i' + "\n\t" +
	  'mv $<.o $(TARGET).o'
print "modified Compile protocol: #{COMPILE_C} ...\n"
end

create_makefile("nwsaprfc")

