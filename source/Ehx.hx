
class Ehx {
	
	var processor : CmdProcessor;
	
	public function new() {
	    processor = new CmdProcessor();
	}
	
	public function render( file , ?scope = null ) {
		var startTime = haxe.Timer.stamp();
		
		if( scope != null )
			processor.addScope( scope );
		
		var r = ~/<%(.*?)%>/sm;
		var results = "";
		var command = "";
		var str = file;
		var inBlock = false;
		while( r.match( str ) ) {
			command = r.matched(1);
			command = preprocessCmd( command );
			if( !inBlock )
				results += r.matchedLeft();
			else {
				var block = ~/\n/.replace( r.matchedLeft() , "\\n" );
				command = "print( '" + block + "' );" + command;
			}
			trace( "command: " + command );
			try {
				var res = processor.process( command );
				trace( "Process: " + res );
				if( res != null ) 
					results += res;
				inBlock = false;
			} catch (ex:CmdError) {
				switch( ex ) {
					case IncompleteStatement:
						trace("Incomplete ... "); // continue prompt
						inBlock = true;
					case InvalidStatement:
						trace("Syntax error. " + ex);
					case InvalidCommand(cmd):
						trace("Execution error. " + cmd);
				}
			}
			try { str = r.matchedRight(); } catch( e : Dynamic ) {}
		}
		results += str;
		
		trace( "(" + ( haxe.Timer.stamp() - startTime ) + " ms) Results: " + results );
		
		return file;
	}
	
	function preprocessCmd( cmd : String ) : String {
		if( StringTools.startsWith( cmd , "=" ) ) {
			cmd = "print("+StringTools.ltrim( cmd.substr( 1 ) ) + ");";
		}
		return cmd;
	}
	
	public static function main() {
		var ehx = new Ehx();
		var scope = {
			str: "hello there",
			num: 12,
			arr: ["abc",123],
			func: function() {
				return "this is from a function!";
			}
		}
		trace( ehx.render( neko.io.File.getContent( "index.ehx" ) , scope ) );
	}
}



import hscript.Expr;

enum CmdError {
  IncompleteStatement;
  InvalidStatement;
  InvalidCommand(s:String);
}

class CmdProcessor {
	/** accumulating command fragments **/
	private var sb:StringBuf;

	/** parses commands **/
	private var parser : hscript.Parser;

	/** interprets commands  **/
	private var interp : hscript.Interp;

	/** list of crossplatform classes **/
	private var rootClasses : List<String>;

	/** list of non-class builtin variables **/
	private var builtins : List<String>;

	public function new() {
		sb = new StringBuf();

		parser = new hscript.Parser();
		interp = new hscript.Interp();

		builtins = Lambda.list(['null', 'true', 'false', 'trace']); 
		rootClasses = Lambda.list(['Array', /*'ArrayAccess',*/ 'Class', 'Date', 'DateTools', 'Dynamic', 'EReg', /*'Enum',*/ 'Float', 'Hash', 'Int', 'IntHash',
			'IntIter', /*'Iterable', 'Iterator',*/ 'Lambda', 'List', 'Math', /*'Null',*/ 'Reflect', 'Std', 'String', 'StringBuf', 'StringTools',
			'Type', /*'Void',*/ 'Xml', 'haxe_BaseCode', 'haxe_FastCell', 'haxe_FastList', 'haxe_Firebug', 
			'haxe_Http', 'haxe_Int32', 'haxe_Log', 'haxe_Md5', /*'haxe_PosInfos',*/ 'haxe_Public', 'haxe_Resource', 'haxe_Serializer', 
			'haxe_Stack', /*'haxe_StackItem',*/ 'haxe_Template', 'haxe_Timer', /*'haxe_TimerQueue', 'haxe_TypeResolver',*/ 'haxe_Unserializer']);

		// make all root classes available to the interpreter
		for( cc in rootClasses )
			interp.variables.set(cc,Type.resolveClass(StringTools.replace(cc,"_",".")));

		for( cc in rootClasses )
			if( interp.variables.get(cc) == null )
				trace("fail: " + cc);

		var _:DateTools;
		var _:Xml;
		var _:haxe.BaseCode;
		var _:haxe.Firebug;
		var _:haxe.Http;
		var _:haxe.Md5;
		var _:haxe.PosInfos;
		var _:haxe.Public;
		var _:haxe.Resource;
		var _:haxe.Serializer;
		var _:haxe.Stack;
		var _:haxe.Template;
		var _:haxe.Timer;
		var _:haxe.Unserializer;
	}
	
	public function addScope( scope : Dynamic ) {
		for( field in Reflect.fields( scope ) )
			interp.variables.set( field , Reflect.field( scope , field ) );
	}

	/**
	process a line of user input
	**/
	public function process(cmd) : String {
		sb.add(cmd);
		var ret;
		try {
			var cmdStr = preprocess(sb.toString());
			ret = interp.execute(parser.parseString(cmdStr));
		} catch (ex:Error) {
			trace( ex );
			if( Type.enumConstructor(ex) == "EUnexpected" && Type.enumParameters(ex)[0] == "<eof>" 
				|| Type.enumConstructor(ex) == "EUnterminatedString" || Type.enumConstructor(ex) == "EUnterminatedComment") {
				throw IncompleteStatement;
			}
			sb = new StringBuf();
			if( Type.enumConstructor(ex) == "EInvalidChar" || Type.enumConstructor(ex) == "EUnexpected")
				throw InvalidStatement;
			throw InvalidCommand(Type.enumConstructor(ex) + ": " + Type.enumParameters(ex)[0]);
		}
		sb = new StringBuf();
		return (ret==null) ? null : Std.string(ret);
	}

	/**
	fix the dot syntax for standard class packages and regex pattern defs
	**/
	private function preprocess(cmdStr) {
		cmdStr = StringTools.replace(cmdStr, "haxe.", "haxe_");

		var reRe = new EReg("~/([^/]+)/([igms]*)", "g");
		cmdStr = reRe.replace(cmdStr, "new EReg(\"$1\",\"$2\")");
		
		if( ~/print\(/smg.match( cmdStr ) )
			cmdStr = "function(){ __programreturn = \"\";" + replacePrint( cmdStr ) + "return __programreturn; }();";
		
		trace( "preprocessed:" + cmdStr );
		
		return cmdStr;
	}
	
	function replacePrint( str ) {
		var ret = new StringBuf();
		var index, endIndex;
		var r = ~/print\(/smg;
		while( r.match( str ) ) {
			// Append the part before finding "print("
			ret.add( r.matchedLeft() );
			index = r.matchedPos().pos + r.matchedPos().len;
			// Find the end of the print()-method
			endIndex = findPrintEndIndex( r.matchedRight() );
			// Append the print content (and remove extra ";" to avoid some errors)
			var print = StringTools.trim( str.substr( index , endIndex ) );
			if( StringTools.endsWith( print , ";" ) ) 
				print = print.substr( 0 , print.length - 1 );
			ret.add( "__programreturn+=Std.string( " + print + ");" );
			// Update the search string (skip the last two chars: ");")
			str = str.substr( index + endIndex + 2 );
		}
		ret.add( str );
		return ret.toString();
	}

	
	function findPrintEndIndex( str ) {
		// Loop through the string to find the index of a non-nested ")"
		var indent = 0;
		var index = 0;
		var char;
		trace( "Finding the last ) in: " + str );
		while( ( char = str.charAt( index ) ) != null ) {
			if( char == "(" ) {
				indent++;
				trace( index + " , " + indent );
			} else if( char == ")" ) {
				indent--;
				trace( index + " , " + indent );
				if( indent == -1 ) 
					return index;
			}
			index++;
		}
		return -1;
	}

	/**
	return a list of all user defined variables
	**/
	private function listVars() : String {
		var builtins = builtins;
		var rootClasses = rootClasses;
		var notBuiltin = function(kk) { return !Lambda.has(builtins, kk) && !Lambda.has(rootClasses, kk); }
		var keys = findVars(notBuiltin);
		var keyArray = Lambda.array(keys);
		keyArray.sort(Reflect.compare);

		if( keyArray.length>0 ) {
			return wordWrap("Current variables: " + keyArray.join(", "));
		} else
			return "There are currently no variables";
	}

	/**
	return a list of all builtin classes
	**/
	private function listBuiltins() : String {
		var rootClasses = rootClasses;
		var isBuiltin = function(kk) { return Lambda.has(rootClasses, kk); }
		var keys = findVars(isBuiltin);
		keys = Lambda.map(keys, function(ii) { return StringTools.replace(ii,'_','.'); });
		var keyArray = Lambda.array(keys);
		keyArray.sort(Reflect.compare);

		if( keyArray.length > 0 ) {
			return wordWrap("Builtins: " + keyArray.join(", "));
		} else
			return "There are no builtins.  Something must have gone wrong.";
	}

	/**
	clear all user defined variables
	**/
	private function clearVars() : String {
		var builtins = builtins;
		var rootClasses = rootClasses;
		var notBuiltin = function(kk) { return !Lambda.has(builtins, kk) && !Lambda.has(rootClasses, kk); }
		var keys = findVars(notBuiltin);

		for( kk in keys )
			interp.variables.remove(kk);
		return null;
	}

	private function findVars(check:String->Bool) {
		var keys = new List<String>();
		for( kk in interp.variables.keys() )
			keys.add(kk);

		var builtins = builtins;
		var rootClasses = rootClasses;
		return keys.filter(check);
	}

	private function wordWrap(str:String) : String {
		if( str.length<=80 )
			return str;

		var words : Array<String> = str.split(" ");
		var sb = new StringBuf();
		var ii = 0; // index of current word
		var oo = 1; // index of current output line
		while( ii<words.length ) {
			while( ii<words.length && sb.toString().length+words[ii].length+1<80*oo ) {
				if( ii!=0 )
					sb.add(" ");
				sb.add(words[ii]);
				ii++;
			}
			if( ii<words.length ) {
				sb.add("\n    ");
				oo++;
			}
		}
		return sb.toString();
	}

}