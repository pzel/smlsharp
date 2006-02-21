(**
 * Copyright (c) 2006, Tohoku University.
 *
 * implementation of primitives on time values.
 * @author YAMATODANI Kiyoshi
 * @version $Id: TimePrimitives.sml,v 1.4 2006/02/18 04:59:40 ohori Exp $
 *)
structure TimePrimitives : PRIMITIVE_IMPLEMENTATIONS =
struct

  (***************************************************************************)

  open RuntimeTypes
  open BasicTypes
  structure RE = RuntimeErrors
  structure SLD = SourceLanguageDatatypes
  structure H = Heap

  (***************************************************************************)

  fun Time_gettimeofday VM heap [dummy] =
      let
        val now = Time.now()
        val seconds = Time.toSeconds now
        val microSeconds =
            Time.toMicroseconds(Time.-(now, Time.fromSeconds seconds))
        val block =
            H.allocateBlock
                heap {size = 0w2, bitmap = 0w0, blockType = RecordBlock}
      in
        H.setFields heap (block, 0w0, [Int seconds, Int microSeconds]);
        [Pointer block]
      end
    | Time_gettimeofday _ _ _ = 
      raise RE.UnexpectedPrimitiveArguments "Time_gettimeofday"

  val primitives =
      [
        {name = "Time_gettimeofday", function = Time_gettimeofday}
      ]

  (***************************************************************************)

end;
