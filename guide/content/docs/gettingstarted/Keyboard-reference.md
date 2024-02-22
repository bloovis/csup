# Keyboard Reference

At any point you can press `?` to see a full list of keyboard bindings.

Here are some from different modes:

Keybindings from thread-view-mode
---------------------------------

          h : Toggle detailed header
          H : Show full message header
          V : Show full message (raw form)
    <enter> : Expand/collapse or activate item
          E : Expand/collapse all messages
          e : Edit draft
          y : Send draft
          l : Edit or add labels for a thread
          o : Expand/collapse all quotes in a message
          n : Jump to next open message
         ^N : Jump to next message and open
          p : Jump to previous open message
         ^P : Jump to previous message and open
          z : Align current message in buffer
          * : Star or unstar message
          N : Toggle unread/read status of message
          r : Reply to a message
          G : Reply to all participants of this message
          f : Forward a message or attachment
          ! : Bounce message to other recipient(s)
          i : Edit alias/nickname for a person
          D : Edit message as new
          s : Save message/attachment to disk
          A : Save all attachments to disk
          P : Publish message/attachment using publish-hook
          S : Search for messages from particular people
          m : Compose message to person
          ( : Subscribe to/unsubscribe from mailing list
          ) : Subscribe to/unsubscribe from mailing list
          | : Pipe message or attachment to a shell command
          a : Archive this thread, kill buffer, and view next
          d : Delete this thread, kill buffer, and view next
          w : Toggle wrapping of text
         .a : Archive this thread and kill buffer
         .d : Delete this thread and kill buffer
         .s : Mark this thread as spam and kill buffer
         .N : Mark this thread as unread and kill buffer
         .. : Just kill this buffer
         ,a : Archive this thread, kill buffer, and view next
         ,d : Delete this thread, kill buffer, and view next
        .s : Mark this thread as spam and kill buffer
        .N : Mark this thread as unread and kill buffer
        .. : Just kill this buffer
        ,a : Archive this thread, kill buffer, and view next
        ,d : Delete this thread, kill buffer, and view next
        ,s : Mark this thread as spam, kill buffer, and view next
        ,N : Mark this thread as unread, kill buffer, and view next
    ,n, ,, : Kill buffer, and view next
        ]a : Archive this thread, kill buffer, and view previous
        ]d : Delete this thread, kill buffer, and view previous
        ]s : Mark this thread as spam, kill buffer, and view previous
        ]N : Mark this thread as unread, kill buffer, and view previous
    ]n, ]] : Kill buffer, and view previous


Keybindings from inbox-mode
---------------------------

     a : Archive thread (remove from inbox)
     A : Archive thread (remove from inbox) and mark read
     | : Refine search

Keybindings from thread-index-mode
----------------------------------

        M : Load 20 more threads
       !! : Load all threads (may list a _lot_ of threads)
       ^G : Cancel current search
        @ : Refresh view
        * : Star or unstar all messages in thread
        N : Toggle new/read status of all messages in thread
        l : Edit or add labels for a thread
        e : Edit message (drafts only)
        S : Mark/unmark thread as spam
        d : Delete/undelete thread
        & : Kill thread (never to be seen in inbox again)
        $ : Flush all changes now
      tab : Jump to next new thread
        r : Reply to latest message in a thread
        G : Reply to all participants of the latest message in a thread
        f : Forward latest message in a thread
        t : Tag/untag selected thread
        T : Tag/untag all threads
        g : Tag matching threads
     +, = : Apply next command to all tagged threads
        # : Force tagged threads to be joined into the same thread
        u : Undo the previous action

Keybindings from line-cursor-mode
---------------------------------

     <down arrow>, j : Move cursor down one line
       <up arrow>, k : Move cursor up one line
             <enter> : Select this item

Keybindings from scroll-mode
----------------------------

                             J, ^E : Down one line
                             K, ^Y : Up one line
                   <left arrow>, h : Left one column
                     <right arrow> : Right one column
          <page down>, <space>, ^F : Down one page
     <page up>, p, <backspace>, ^B : Up one page
                                ^D : Down one half page
                                ^U : Up one half page
                      <home>, ^, 1 : Jump to top
                          <end>, 0 : Jump to bottom
                                 [ : Jump to the left
                                 / : Search in current buffer
                                 n : Jump to next search occurrence in buffer

Global keybindings
------------------

        q : Quit Sup, but ask first
        Q : Quit Sup immediately
        ? : Show help
        b : Switch to next buffer
        B : Switch to previous buffer
        x : Kill the current buffer
        ; : List all buffers
        C : List contacts
       ^L : Redraw screen
     \, F : Search all messages
        U : Show all unread messages
        L : List labels
        P : Poll for new messages
        { : Poll for new messages from unusual sources
     m, c : Compose new message
       ^G : Do nothing
        R : Edit most recent draft message
        I : Show the Inbox buffer
        H : Clear all hooks
        ~ : Show the Console buffer
       Oc : Reload colors
       Ok : Rerun keybindings hook

