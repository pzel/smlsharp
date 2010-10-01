(*
 * lexical structures of IML.
 *   the part of constant specifications is based on 
 *   that of the SML New Jersye implementation
 * @copyright (c) 2006, Tohoku University.
 * @author Atsushi Ohori
 * @author Liu Bochao
 * @author YAMATODANI Kiyoshi
 * @version $Id: iml.lex,v 1.42 2008/02/28 07:36:06 bochao Exp $
 *)

structure T = Tokens
structure UE = UserError
structure SS = Substring

type svalue = T.svalue
type ('a,'b) token = ('a,'b) T.token
type lexresult= (svalue,Loc.pos) token
type pos = Loc.pos
exception Error

datatype stringType = STRING | CHAR | NOSTR

type arg =
{
  fileName : string,
  isPrelude : bool,
  errorPrinter : (string * pos * pos) -> unit,
  stringBuf : string list ref,
  stringStart : pos ref,
  stringType : stringType ref,
  commentStart : Loc.pos list ref,
  anyErrors : bool ref,
  lineMap : {lineCount : int, beginPos : int} list ref,
  lineCount : int ref,
  charCount : int ref,
  initialCharCount : int
}

(*
val error = Error.printError
 *)

(* NOTE: the length of eol can be 2 on DOS/Windows. *)
fun newLine (pos, eolString, arg : arg) =
    (
(* Note: lineMap is updated by Parser, not here.
      #ln arg := (!(#ln arg)) + 1;
      #lineMap arg :=
      {lineCount = !(#ln arg), beginPos = pos + size eolString}
      :: (!(#lineMap arg))
*)
    )
fun currentPos (pos, offset, arg : arg) =
    let
      (*  pos is the number of chars which has been read by this lexer.
       * Because a new lexer is created at each time when any error is found,
       * it means that this pos is not always started from the beginning of
       * the current source.
       *  On the other hand, the lineMap records absolute positions of
       * newlines. These positions start from the beginning of the current
       * source.
       *  The initialCharCount holds the absolute position of location in the
       * source where the current lexer begins to scan.
       *  The next line converts the pos into an absolute one.
       *)
      val absolutePos = pos + (#initialCharCount arg)
    in
      (*  Then, we search for a lineMap entry for the line which contains the
       * location that is pointed by the absolutePos.
       *  Entries in the lineMap are sorted in descending order of line count.
       *  An entry for the line which has been read last is at the top of the
       * lineMap.
       *  Therefore, we scan the lineMap from the top to the last.
       *)
      case
        List.find
          (fn{beginPos, ...} => beginPos <= absolutePos)
          (!(#lineMap arg))
       of
        SOME{lineCount, beginPos} =>
        Loc.makePos 
          {
            fileName = #fileName arg,
            line = lineCount,
            col = absolutePos - beginPos + offset + 1 (* first column is 1. *)
          }
      | NONE =>
        let 
          val message = 
              "lineCount of " ^ Int.toString absolutePos ^ " is not found."
        in
          #errorPrinter arg (message, Loc.nopos, Loc.nopos); Loc.nopos
      (*
          raise Control.Bug message
       *)
        end
            
    end
fun left (pos, arg) = currentPos(pos, 0, arg)
fun right (pos, size, arg) = currentPos(pos, size - 1, arg)
fun addString (buffer, string) = buffer := string :: (!buffer)
fun strToLoc (text, pos, arg) = 
    let
      val leftPos = left(pos, arg)
      val rightPos = right(pos, String.size text, arg)
    in
      (leftPos, rightPos)
    end
fun addChar (buffer, string) = buffer := String.str string :: (!buffer)
fun makeString (buffer) = concat (rev (!buffer)) before buffer := nil

fun eof ({commentStart, stringStart, stringType, anyErrors, errorPrinter,
          ...}:arg) =
    (case !commentStart of
       nil => ()
     | pos::_ => (errorPrinter ("unclosed comment", pos, Loc.nopos);
                  anyErrors := true);
     case !stringType of
       NOSTR => ()
     | STRING => (errorPrinter ("unclosed string", !stringStart, Loc.nopos);
                  anyErrors := true)
     | CHAR => (errorPrinter ("unclosed character constant",
                              !stringStart, Loc.nopos);
                anyErrors := true);
     T.EOF (Loc.nopos, Loc.nopos))

local
  fun cvtnum scanner (s, i, loc) =
      let val (v, remain) = valOf(scanner SS.getc (SS.triml i (SS.full s)))
      in
        if SS.isEmpty remain
        then v
        else raise Control.BugWithLoc ("incomplete conversion.", loc)
      end
      handle exn as General.Overflow => 
             raise UE.UserErrors [(loc, UE.Error, exn)]
  fun cvti radix (s, i, loc) = cvtnum (BigInt.scan radix) (s, i, loc)
  fun cvtw radix (s, i, loc) = cvtnum (Word32.scan radix) (s, i, loc)
in
val atoi = cvti StringCvt.DEC
val atow = cvtw StringCvt.DEC
val xtoi = cvti StringCvt.HEX
val xtow = cvtw StringCvt.HEX
end (* local *)
fun isSuffix char string =
    0 < size string andalso String.sub (string, size string - 1) = char
%%
%s A S F;
%header (functor MLLexFun(structure Tokens: ML_TOKENS));
%arg (arg as 
      {
        fileName,
        isPrelude,
        errorPrinter,
        stringBuf,
        stringStart,
        stringType,
        commentStart,
        anyErrors,
        lineMap,
        lineCount,
        charCount,
        initialCharCount
      });

quote="'";
underscore="\_";
alpha=[A-Za-z];
digit=[0-9];
idchars={alpha}|{digit}|{quote}|{underscore};
id=({alpha}|{quote}){idchars}*;
ws=("\012"|[\t\ ])*;
eol=("\013\010"|"\010"|"\013");
sym=[!%&$+/:<=>?@~`|#*]|\-|\^;
symbol={sym}|\\;
num=[0-9]+;
frac="."{num};
exp=[eE](~?){num};
real=(~?)(({num}{frac}?{exp})|({num}{frac}{exp}?));
hexnum=[0-9a-fA-F]+;
%%
<INITIAL>{ws} => (continue());
<INITIAL>{eol} => (newLine(yypos, yytext, arg); continue ());
<INITIAL>"_absnamespace" => (T.ABSNAMESPACE (left(yypos,arg),right(yypos,13,arg)));
<INITIAL>"abstype" => (T.ABSTYPE (left(yypos,arg),right(yypos,7,arg)));
<INITIAL>"andalso" => (T.ANDALSO (left(yypos,arg),right(yypos,7,arg)));
<INITIAL>"and" => (T.AND (left(yypos,arg),right(yypos,3,arg)));
<INITIAL>"as" => (T.AS (left(yypos,arg),right(yypos,2,arg)));
<INITIAL>"__attribute__" => (T.ATTRIBUTE (left(yypos,arg),right(yypos,13,arg)));
<INITIAL>"case" => (T.CASE (left(yypos,arg),right(yypos,4,arg)));
<INITIAL>"_cast" => (T.CAST (left(yypos,arg),right(yypos,5,arg)));
<INITIAL>"_cdecl" => (T.CDECL (left(yypos,arg),right(yypos,6,arg)));
<INITIAL>"datatype" => (T.DATATYPE (left(yypos,arg),right(yypos,8,arg)));
<INITIAL>"do" => (T.DO (left(yypos,arg),right(yypos,2,arg)));
<INITIAL>"else" => (T.ELSE (left(yypos,arg),right(yypos,4,arg)));
<INITIAL>"end" => (T.END (left(yypos,arg),right(yypos,3,arg)));
<INITIAL>"eqtype" => (T.EQTYPE (left(yypos,arg),right(yypos,6,arg)));
<INITIAL>"exception" => (T.EXCEPTION (left(yypos,arg),right(yypos,9,arg)));
<INITIAL>"_export" => (T.EXPORT (left(yypos,arg),right(yypos,7,arg)));
<INITIAL>"_external" => (T.EXTERNAL (left(yypos,arg),right(yypos,9,arg)));
<INITIAL>"_ffiapply" => (T.FFIAPPLY (left(yypos,arg),right(yypos,9,arg)));
<INITIAL>"fn" => (T.FN (left(yypos,arg),right(yypos,2,arg)));
<INITIAL>"fun" => (T.FUN (left(yypos,arg),right(yypos,3,arg)));
<INITIAL>"functor" => (T.FUNCTOR (left(yypos,arg),right(yypos,7,arg)));
<INITIAL>"handle" => (T.HANDLE (left(yypos,arg),right(yypos,6,arg)));
<INITIAL>"if" => (T.IF (left(yypos,arg),right(yypos,2,arg)));
<INITIAL>"_import" => (T.IMPORT (left(yypos,arg),right(yypos,7,arg)));
<INITIAL>"_require" => (T.REQUIRE (left(yypos,arg),right(yypos,8,arg)));
<INITIAL>"in" => (T.IN (left(yypos,arg),right(yypos,2,arg)));
<INITIAL>"include" => (T.INCLUDE (left(yypos,arg),right(yypos,7,arg)));
<INITIAL>"infix" => (T.INFIX (left(yypos,arg),right(yypos,5,arg)));
<INITIAL>"infixr" => (T.INFIXR (left(yypos,arg),right(yypos,6,arg)));
<INITIAL>"nonfix" => (T.NONFIX (left(yypos,arg),right(yypos,6,arg)));
<INITIAL>"let" => (T.LET (left(yypos,arg),right(yypos,3,arg)));
<INITIAL>"local" => (T.LOCAL (left(yypos,arg),right(yypos,5,arg)));
<INITIAL>"of" => (T.OF (left(yypos,arg),right(yypos,2,arg)));
<INITIAL>"op" => (T.OP (left(yypos,arg),right(yypos,2,arg)));
<INITIAL>"open" => (T.OPEN(left(yypos,arg),right(yypos,4,arg)));
<INITIAL>"orelse" => (T.ORELSE (left(yypos,arg),right(yypos,6,arg)));
<INITIAL>"_namespace" => (T.NAMESPACE (left(yypos,arg),right(yypos,10,arg)));
<INITIAL>"_NULL" => (T.NULL (left(yypos,arg),right(yypos,5,arg)));
<INITIAL>"raise" => (T.RAISE (left(yypos,arg),right(yypos,5,arg)));
<INITIAL>"rec" => (T.REC (left(yypos,arg),right(yypos,3,arg)));
<INITIAL>"sharing" => (T.SHARING (left(yypos,arg),right(yypos,7,arg)));
<INITIAL>"sig"=> (T.SIG (left(yypos,arg),right(yypos,3,arg)));
<INITIAL>"signature" => (T.SIGNATURE (left(yypos,arg),right(yypos,9,arg)));
<INITIAL>"_sizeof" => (T.SIZEOF (left(yypos,arg),right(yypos,7,arg)));
<INITIAL>"_stdcall" => (T.STDCALL (left(yypos,arg),right(yypos,8,arg)));
<INITIAL>"struct" => (T.STRUCT (left(yypos,arg),right(yypos,6,arg)));
<INITIAL>"structure" => (T.STRUCTURE (left(yypos,arg),right(yypos,9,arg)));
<INITIAL>"then" => (T.THEN (left(yypos,arg),right(yypos,4,arg)));
<INITIAL>"type" => (T.TYPE (left(yypos,arg),right(yypos,4,arg)));
<INITIAL>"use" => (T.USE (left(yypos,arg),right(yypos,3,arg)));
<INITIAL>"_useobj" => (T.USEOBJ (left(yypos,arg),right(yypos,7,arg)));
<INITIAL>"val" => (T.VAL (left(yypos,arg),right(yypos,3,arg)));
<INITIAL>"where" => (T.WHERE (left(yypos,arg),right(yypos,5,arg)));
<INITIAL>"while" => (T.WHILE (left(yypos,arg),right(yypos,5,arg)));
<INITIAL>"with" => (T.WITH (left(yypos,arg),right(yypos,4,arg)));
<INITIAL>"withtype" => (T.WITHTYPE (left(yypos,arg),right(yypos,8,arg)));
<INITIAL>":>" => (T.OPAQUE (left(yypos,arg),right(yypos,2,arg)));
<INITIAL>"*" => (T.ASTERISK(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>"#" => (T.HASH(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>"(" => (T.LPAREN(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>")" => (T.RPAREN(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>"," => (T.COMMA(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>"->" => (T.ARROW (left(yypos,arg),right(yypos,2,arg)));
<INITIAL>"." => (T.PERIOD (left(yypos,arg),right(yypos,1,arg)));
<INITIAL>"..." => (T.PERIODS (left(yypos,arg),right(yypos,3,arg)));
<INITIAL>":" => (T.COLON(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>";" => (T.SEMICOLON(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>"=" => (T.EQ(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>"=>" => (T.DARROW (left(yypos,arg),right(yypos,2,arg)));
<INITIAL>"[" => (T.LBRACKET(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>"]" => (T.RBRACKET(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>"_" => (T.UNDERBAR(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>"{" => (T.LBRACE(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>"|" => (T.BAR(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>"}" => (T.RBRACE(left(yypos,arg),right(yypos,1,arg)));
<INITIAL>{id} =>
    (let
       val loc = strToLoc(yytext, yypos, arg)
       val textSize = String.size yytext
     in
       if String.isPrefix "''" yytext
       then
         T.EQTYVAR(String.substring(yytext, 2, textSize - 2), #1 loc, #2 loc)
       else
       if #isPrelude arg andalso
         String.isPrefix "'_" yytext andalso
         isSuffix #"'" yytext
       then T.ID(String.substring(yytext, 1, textSize - 2), #1 loc, #2 loc)
       else
       if String.isPrefix "'" yytext
       then T.TYVAR(String.substring(yytext, 1, textSize - 1), #1 loc, #2 loc)
       else T.ID(yytext, #1 loc, #2 loc)
       end);
<INITIAL>{symbol}+ =>
        (T.ID
          (yytext, left(yypos, arg), right(yypos, String.size yytext, arg)));
<INITIAL>{real} =>
        (T.REAL
          (yytext, left(yypos, arg), right(yypos, String.size yytext, arg)));
<INITIAL>{num} =>
        (let val loc = strToLoc(yytext, yypos, arg)
             val con = if String.isPrefix "0" yytext then T.INT0 else T.INT
         in con (atoi(yytext, 0, loc), #1 loc, #2 loc)
         end);
<INITIAL>~{num} =>
        (let val loc = strToLoc(yytext, yypos, arg)
         in T.INT (atoi(yytext, 0, loc), #1 loc, #2 loc)
         end);
<INITIAL>"0w"{num} => 
        (let val loc = strToLoc(yytext, yypos, arg)
         in T.WORD (atow(yytext, 2, loc), #1 loc, #2 loc)
         end);
<INITIAL>"0x"{hexnum} => 
        (let val loc = strToLoc(yytext, yypos, arg)
         in T.INT (xtoi(yytext, 2, loc), #1 loc, #2 loc)
         end);
<INITIAL>"~0x"{hexnum} =>
        (let val loc = strToLoc(yytext, yypos, arg)
         in T.INT (BigInt.~(xtoi(yytext, 3, loc)), #1 loc, #2 loc)
         end);
<INITIAL>"0wx"{hexnum} =>
        (let val loc = strToLoc(yytext, yypos, arg)
         in T.WORD (xtow(yytext, 3, loc), #1 loc, #2 loc)
         end);
<INITIAL>\" => (
                 stringBuf := nil; 
                 stringStart := left(yypos, arg);
                 stringType := STRING;
                 YYBEGIN S;
                 continue()
               );
<INITIAL>\#\" => (
                    stringBuf := nil; 
                    stringStart := left(yypos, arg);
                    stringType := CHAR;
                    YYBEGIN S;
                    continue()
                  );
<INITIAL>"(*" => (YYBEGIN A;
                  commentStart := left(yypos, arg) :: !commentStart;
                  continue()
 (* Unlike "(*", unmatched "*)" should not cause parse error. It should
  * be regarded as two tokens "*" and ")". *)
                 );
<INITIAL>\h => (
                 errorPrinter
                 (
                   "non-Ascii character",
                   left(yypos, arg),
                   right(yypos, 1, arg)
                 );
                 anyErrors := true;
                 continue()
               );
<INITIAL>. => (
                errorPrinter
                ("illegal token", left(yypos, arg), right(yypos, 1, arg));
                anyErrors := true;
                continue()
              );
<A>"(*"  => (commentStart := left(yypos, arg) :: !commentStart;
             continue());
<A>{eol} => (newLine(yypos, yytext, arg); continue ());
<A>"*)" => (
            case !commentStart of
              _::nil => (commentStart := nil; YYBEGIN INITIAL)
            | _::t => commentStart := t
            | nil => raise Control.Bug "unmatched close comment";
            continue()
           );
<A>. => (continue());
<S>\" => (
           let
             val s = makeString stringBuf
             val s = if size s <> 1 andalso !stringType = CHAR
                     then
                       (
                         errorPrinter
                         (
                           "character constant not length 1",
                           left(yypos, arg),
                           right(yypos, 1, arg) (* pos of double quote *)
                         );
                         anyErrors := true;
                         if 0 = size s then "?" else s
                       )
                     else s
             val t = (s, !stringStart, right(yypos, 1, arg))
           in
             YYBEGIN INITIAL;
             case !stringType before stringType := NOSTR of
               STRING => T.STRING t
             | CHAR => T.CHAR t
             | NOSTR => raise Control.Bug "close string"

           end
         );
<S>{eol} => (
              errorPrinter
              ("unclosed string", left(yypos, arg), right(yypos, 1, arg));
              anyErrors := true;
              stringType := NOSTR;
              newLine(yypos, yytext, arg); 
              YYBEGIN INITIAL;
              T.STRING
              (makeString stringBuf, !stringStart, right(yypos, 1, arg))
            );
<S>\\{eol} => (newLine(yypos, yytext, arg); YYBEGIN F; continue());
<S>\\{ws} => (YYBEGIN F; continue());
<S>\\a => (addString(stringBuf, "\007"); continue());
<S>\\b => (addString(stringBuf, "\008"); continue());
<S>\\f => (addString(stringBuf, "\012"); continue());
<S>\\n => (addString(stringBuf, "\010"); continue());
<S>\\r => (addString(stringBuf, "\013"); continue());
<S>\\t => (addString(stringBuf, "\009"); continue());
<S>\\v => (addString(stringBuf, "\011"); continue());
<S>\\\\ => (addString(stringBuf, "\\"); continue());
<S>\\\" => (addString(stringBuf, "\""); continue());
<S>\\\^[@-_] => (
                  addChar
                  (
                    stringBuf,
                    Char.chr(Char.ord(String.sub(yytext, 2)) - (Char.ord #"@"))
                  );
                  continue()
                );
<S>\\\^. => (
              errorPrinter
              (
                "illegal control escape; must be one of \
                \@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_",
                left(yypos, arg),
                right(yypos, size yytext, arg)
              );
              anyErrors := true;
              continue()
            );
<S>\\[0-9]{3} => (let
                    val x = Char.ord(String.sub(yytext, 1)) * 100
                            + Char.ord(String.sub(yytext, 2)) * 10
                            + Char.ord(String.sub(yytext, 3))
                            - ((Char.ord #"0") * 111)
                  in
                    if x > 255
                    then
                      (
                        errorPrinter
                        (
                          "illegal ascii escape",
                          left(yypos, arg),
                          right(yypos, size yytext, arg)
                        );
                        anyErrors := true
                      )
                    else addChar(stringBuf, Char.chr x);
                    continue()
                  end);
<S>\\u[0-9a-fA-F]{4} =>
                 (let
                    fun parseHexInt string =
                        StringCvt.scanString (Int.scan StringCvt.HEX) string
                    val x =
                        valOf(parseHexInt (String.extract (yytext, 2, NONE)))
                  in
                    if Char.maxOrd < x
                    then
                      (
                        errorPrinter
                        (
                          "illegal ascii escape",
                          left(yypos, arg),
                          right(yypos, size yytext, arg)
                        );
                        anyErrors := true
                      )
                    else addChar(stringBuf, Char.chr x);
                    continue()
                  end);
<S>\\  => (
            errorPrinter
            ("illegal string escape", left(yypos, arg), right(yypos, 1, arg));
            anyErrors := true;
            continue()
          );
<S>[\000-\031] => (
                    errorPrinter
                    (
                      "illegal non-printing character in string",
                      left(yypos, arg),
                      right(yypos, 1, arg)
                    );
                    anyErrors := true;
                    continue()
                  );
<S>({idchars}|{sym}|\[|\]|\(|\)|{quote}|[,.;^{}])+|.  =>
                (addString(stringBuf, yytext); continue());
<F>{eol} => (newLine(yypos, yytext, arg); continue());
<F>{ws} => (continue());
<F>\\  => (YYBEGIN S; continue());
<F>.  => (
           errorPrinter
           ("unclosed string", left(yypos, arg), right(yypos, 1, arg));
           anyErrors := true;
           stringType := NOSTR;
           YYBEGIN INITIAL;
           T.STRING
           (makeString stringBuf, !stringStart, right(yypos, 1, arg))
         );
. => (T.SPECIAL(yytext, left(yypos, arg), right(yypos, 1, arg)));
