(**
 * Copyright (c) 2006, Tohoku University.
 *
 * coordinates whole phases of the compiler.
 *
 * @author YAMATODANI Kiyoshi
 * @version $Id: TOP.sig,v 1.18 2006/02/18 04:59:30 ohori Exp $
 *)
signature TOP =
sig

  (***************************************************************************)

  (**
   *)
  datatype interactionMode =
           (** print prompt, continue session on error. *)
           Interactive
         | (** no prompt. *)
           NonInteractive of
               {(** stop session on error if true. *) stopOnError : bool}

  (**
   *  A context holds global status of compilation, such as global table.
   *  Contexts are generated by the "initialize" function,
   * and updated by the "run" function.
   *)
  type context

  (** parameters to create a context. *)
  type contextParameter =
      {
        session : SessionTypes.Session,
        standardOutput : ChannelTypes.OutputChannel,
        standardError : ChannelTypes.OutputChannel,
        loadPathList : string list,
        getVariable : string -> string option
      }

  (**
   * source from which program is obtained.
   *)
  type source = 
       {
         (** interactionMode of the session. *)
         interactionMode : interactionMode,
         (** a channel from which the source code is read. *)
         initialSource : ChannelTypes.InputChannel,
         (** the name of the initialSource.
          * This string is used in the error/warning messages. *)
         initialSourceName : string,
         (** a function which returns the "current" directory. *)
         getBaseDirectory : unit -> string
       }

  (***************************************************************************)

  (**
   * initialize system.
   * <p>
   * You must this function at first before using the compiler.
   * </p>
   * @parameters
   *    {session, standardOutput, standardError, loadPathList, getVariable}
   * @param session the session instance.
   * @param standardOutput a channel to be used as standard output.
   *                    Prompt is printed to this channel.
   * @param standardError a channel to be used as standard error.
   *                    Erro messages are printed to this channel.
   * @param loadPathList list of directories to search for files to load by
   *                   'use' directive.
   * @param getVariable a function which returns the value of a variable.
   * @return new context
   *)
  val initialize : contextParameter -> context

  val pickle : context -> Pickle.outstream -> unit

  val unpickle : contextParameter -> Pickle.instream -> context

  (**
   * compile (and execute) a source code.
   * <p>
   * The top loop runs in either of interactive mode or non-interactive mode.
   * If interactive, prompt is printed.
   * And the top loop continues even when any user error or compile
   * bug is detected, if interactive.
   * If non-interactive, any error or bug stops the loop.
   * </p>
   * @params context source
   * @param context the context, which is updated by this function.
   * @return true if compile and session.execute succeed.
   *)
  val run : context -> source -> bool

  (***************************************************************************)

end
