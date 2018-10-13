# lita-stacker

At Change.org we use Slack as a medium for all kinds of things, from the
mission-critical to the utterly banal. Stacking is … somewhere in the middle.

We stack in a channel to manage the flow of the conversation in a meeting. It
serves several purposes:

1. It cuts down on interruptions from squeaky wheels / dominant voices
1. It levels the field a bit for remote participants
1. It can also help folks who are attending a meeting in a language other than their native tongue.

These are all very important diversity & inclusion goals for meeting management.

## Installation

Add lita-stacker to your Lita instance's Gemfile:

``` ruby
gem "lita-stacker"
```


## Usage

(**NOTE:** I am using a testing Slack instance to give a generic name to the
bot. Unfortunately the colors it chose for our messages are red and green.
Please let us know if this makes it harder to distinguish, and we will try to
change the colors in the images).

### Adding to the Stack

When you want to add to the conversation in a meeting, you add yourself to the stack:

![stack (command)](https://raw.githubusercontent.com/change/lita-stacker/master/i/stack_self.png)

You can also stack for someone else:

![stack @Vladimir](https://raw.githubusercontent.com/change/lita-stacker/master/i/stack_others.png)

### Showing the Stack

If you’re not sure what the stack currently looks like, you can peek at its current state:

![stack show](https://raw.githubusercontent.com/change/lita-stacker/master/i/stack_show.png)

(This command can also be invoked as `stack[s] {show|list}`)

### Leaving the Stack

If you get tired of waiting for Godot, (or if your question or comment was
addressed by someone higher in the stack), you can jump out at any time:

![unstack](https://raw.githubusercontent.com/change/lita-stacker/master/i/unstack_self.png)

(This command can also be invoked as `stack {drop|done}`)

And you can see that you’re no longer there (using an alternative command):

![stacks list](https://raw.githubusercontent.com/change/lita-stacker/master/i/stack_show_missing.png)

You can also take care of this for someone else (perhaps someone who left to
go to another meeting, and forgot to unstack. Or perhaps it was not you who
came to deliver the message last night):

![unstack @Godot](https://raw.githubusercontent.com/change/lita-stacker/master/i/unstack_others.png)

Note that the bot announces who next has the floor, and asks them to unstack when they are done.

### Clearing the Stack

We can clear the whole slate:

![stack clear](https://raw.githubusercontent.com/change/lita-stacker/master/i/stack_clear.png)

(This command can also be invoked as `stacks clear`)

Looks like Vladimir and Estragon will have to wait another day for Godot.
Let’s leave them to contemplate their existence.

### Getting Help

Finally, there are help commands for all of this. say `@litabot help stack`
and the bot will reply to you privately with a list of commands. (**Tip:** if you
start in a private conversation with the bot you can drop the `@litabot` part
of that (or any) command)

![help stack](https://raw.githubusercontent.com/change/lita-stacker/master/i/stack_help.png)


## License

[MIT](http://opensource.org/licenses/MIT)
