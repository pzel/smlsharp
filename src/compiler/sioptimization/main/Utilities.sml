(**
 * Copyright (c) 2006, Tohoku University.
 *
 * @author NGUYEN Huu-Duc
 * @version $Id: Utilities.sml,v 1.1 2006/02/20 14:48:29 kiyoshiy Exp $
 *)

structure SI = SymbolicInstructions
               
structure Entry_ord:ordsig = struct 
type ord_key = SI.entry
               
fun compare ({id = id1, displayName = displayName1},{id = id2, displayName = displayName2}) =
    ID.compare(id1,id2)
end
  
structure EntryMap = BinaryMapFn(Entry_ord)
structure EntrySet = BinarySetFn(Entry_ord)
                     
