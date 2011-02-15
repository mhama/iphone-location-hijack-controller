#
# create just one .m file to do all.
# 

# To install the feature to your project, just add the resulted 
# CLLocationManager+Hijack.m, cocoahttpserver.a and all is done.

# read CLLocationManager+Hijack.m, location.html and embed it to CLLocationManager+Hijack.m

# escape ' " (quotation)'s and \ (backslash)'s.
def escapeHTMLForCSourceFile(html)
	return  html.gsub(/\\|'|"/) { |c| "\\#{c}" }
end

# comment-out import directives for cocoahttpserver.
def excludeimport(line)
	if line =~ /\#import\s+\"HTTP.*\.h\"/ or line =~ /\#import\s+\"CLLocationManager\+Hijack\.h\"/ then
		return "//embedded " + line
	end
	return line
end


serverdir = "cocoahttpserver/";

hfiles = [
serverdir+"HTTPServer.h",
serverdir+"HTTPConnection.h",
serverdir+"HTTPResponse.h",
serverdir+"HTTPAsyncFileResponse.h",
serverdir+"HTTPDynamicFileResponse.h",
serverdir+"HTTPDataResponse.h",
serverdir+"HTTPRedirectResponse.h",
"src/CLLocationManager+Hijack.h",
];

mainsrcfile = "src/CLLocationManager+Hijack.m"

mfile = File.open(mainsrcfile, "r")
efile = File.open("src/location.html", "r")
ofile = File.new("CLLocationManager+HijackAll.m", "w")

ofile.puts ""
ofile.puts "#ifdef DEBUG // only for debug mode (this can be changed to whatever)"
ofile.puts ""

# add up header files
hfiles.each {|path|
	ofile.puts "//============================= contents of <" + path + ">"
	hfile = File.open(path, "r")
	hfile.each{|line|
		ofile.puts excludeimport(line)
	}
	hfile.close
}

# add main implementation file, with embedded HTML contents
ofile.puts "//============================= contents of <" + mainsrcfile + ">"

mfile.each {|line|
	if line =~ /\#define\ CONTROLLER\_HTML/ then
		ofile.puts "#define CONTROLLER_HTML \\"
		efile.each{|line2|
			line2 = line2.chop
			lineout = '"' + escapeHTMLForCSourceFile(line2) + '\\n" \\'
			ofile.puts lineout
		}
		ofile.puts ""
	else
		ofile.puts excludeimport(line)
	end
}

ofile.puts "#endif // #ifdef DEBUG"

ofile.close
efile.close
mfile.close
