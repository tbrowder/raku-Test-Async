use v6;

=begin pod
=NAME

C<Test::Async::Base> – this test bundle contains all the base test tools

=SYNOPSIS

    use Test::Async::Base;
    use Test::Async;
    plan 1;
    pass "Hello world!";
    done-testing

=DESCRIPTION

This bundle is supposed to provide same test tools, as the standard Raku L<C<Test>|https://docs.raku.org/type/Test>. So that

    use Test::Async;
    plan ...;
    ...; # Do tests
    done-testing

would be the same as:

    use Test;
    plan ...;
    ...; # Do tests
    done-testing

For this reason this document only tells about differences between the two.

Test tools resulting in either I<ok> or I<not ok> messages return either I<True> or I<False> depending on test outcome.
C<skip> always considered to be successful and thus returns I<True>.

=ATTRIBUTES

=head2 C<Str:D $.FLUNK-message>

The message set with C<test-flunks>.

=head2 C<Numeric:D $.FLUNK-count>

Number of tests expected to flunk. Reduces with each next test completing.

See C<take-FLUNK>.

=METHODS

=head2 C<take-FLUNK(--> Str)>

If C<test-flunks> is in effect then method returns its message and decreases C<$.FLUNK-count>.

=head2 C<multi expected-got(Str:D $expected, Str:D $got, Str :$exp-sfx, Str :$got-sfx --> Str)>
=head2 C<multi expected-got($expected, $got, :$gist, :$quote, *%c)>

Method produces standardized I<"expected ... but got ..."> messages.

The second candidate is used for non-string values. It stringifies them using
L<C<Test::Async::Utils>|Utils.md> C<stringify> routine and then passes over to the first candidate for formatting alongside with
named parameters captured in C<%c>.

Named parameters:

=item C<:$exp-sfx> - suffix for "expected", a string which will be inserted after it.
=item C<:$got-sfx> – suffix for "got"
=item C<:$gist> - enforces use of method C<gist> to stringify values
=item C<:$quote> - enforces use of quotes around the stringified values

=head2 C<cmd-settestflunk>

Handler for C<Event::Cmd::SetTestFlunk> defined by this bundle.

=head1 TEST TOOLS

=head2 C<diag +@msg>

Unlike the standard L<C<Test>|https://docs.raku.org/type/Test> C<diag>, accepts a list too allowing similar usage as with C<say> and C<note>.

=head2 C<skip-remaining($message, Bool :$global?)>

Skips all remaining tests in current suite. If C<$global> is set then it's the same as invoking C<skip-remaining> on
all suite parents, including the topmost suite.

=head2 C<todo-remaining(Str:D $message)>

Mark all remaining tests of the current suite as I<TODO>.

=head2 C<multi subtest(Pair $what, Bool:D :$async=False, Bool:D :$instant=False, :$hidden=False, *%plan)>
=head2 C<multi subtest(Str:D $message, Callable:D \code, Bool:D :$async=False, Bool:D :$instant=False, :$hidden=False, *%plan)>
=head2 C<multi subtest(Callable:D \code, Bool:D :$async=False, Bool:D :$instant=False, :$hidden=False, *%plan)>

C<subtest> is a way to logically group a number of tests together. The default C<subtest> behaviour is no different from
what is described in L<C<Test>|https://docs.raku.org/type/Test#sub_subtest>. But additionally we can invoke it:

=item asynchronously
=item in random order with other C<subtest>s of the same nesting level
=item randomly and asynchronously at the same time

A C<subtest> could also kind of hide itself behind another test tool.

C<subtest> returns a L<C<Promise>|https://docs.raku.org/type/Promise> kept with I<True> or I<False> depending on
C<subtest> pass/flunk status.

=head3 Invocation modes of C<subtest>

The asynchronous invocation means that a C<subtest> will be run in a new dedicated thread. The random invocation means
that C<subtest> invocation is postponed until the suite code ends. Then all postponed subtests will be pulled and
invoked in a random order.

It is possible to combine both async and random modes which might add even more stress to the code tested.

I<Some more information about C<Test::Async> job management can be found in
L<C<Test::Async::Manual>|Manual.md>,
L<C<Test::Async::Hub>|Hub.md>,
L<C<Test::Async::JobMgr>|JobMgr.md>>

The particular mode of operation is defined either by C<plan> keys C<parallel> or C<random>, or by subtest named
parameters C<async> or C<instant>. The named parameters take precedence over plan parameters:

=item if C<instant> is set then C<plan>'s C<random> is ignored
=item if C<async> is set then C<plan>'s C<parallel> is ignored

For example, let's assume that our current suite is configured for random execution of subtest. Then

    subtest "foo", :instant, {
        ...
    }

would result in the C<subtest> be invoked right away, where it's declaration is encountered, without postponing.
Similarly, if C<parallel> plan parameter is in effect, C<:instant> will overrule it so it will run right here, right
now!

Adding C<:async> named parameter too will invoke the subtest instantly and asynchronously. And this also means that
a subtest invoked this way won't be counted as a job by
L<C<Test::Async::JobMgr>|JobMgr.md>.
In other words, we treat C<:instant> as: I<bypass any queue, just do it here and now!>

Another edge case is using C<:async> with C<random>. In this case the subtest will be postponed. But when time to invoke
subtests comes this particular one will get his dedicated thread no matter what C<parallel> is set to.

Any other named parameters passed to a C<subtest> are treated as plan keys.

Subset topic variable is set to the backing suite object. For example, this is an excerpt from I<t/060-subtest.t>:

    subtest "subtest topic" => {
        .plan: 1;
        .cmp-ok: $_, '===', test-suite, "topic is set to the test suite object";
    }

The example is the recommended mode of operation when a subtest is invoked in a module. In other words, the above
example could be written as:

    Test::Async::Hub.test-suite.subtest "subtest topic" => {
        .plan: 1;
        .cmp-ok: $_, '===', test-suite, "topic is set to the test suite object";
    }

and this is the way it must be used in a module. See
L<C<Test::Async>|../Async.md>
and L<C<Test::Async::CookBook>|CookBook.md>
for more details.

=head3 Hidden C<subtest>

C<:hidden> named parameter doesn't change how a subtest runs but rather how it reports itself. A hidden subtest pretends
to be integral part of test tool method which invoked it. It means two things:

=item flunked test tools called by subtest code won't report their location (file and line)
(I<implemented by L<C<Test::Async::Reporter::TAP>|Reporter/TAP.md> and might not be supported by 3rd party reporters>)
=item flunked subtest would report location of the test tool method which invoked it

The primary purpose of this mode is to provide means of implementing compound test tools. I.e. tools which consist of
two or more tests which outcomes are to be reported back to the user. The most common implementation of such tool method
would look like:

    method compound-tool(..., Str:D $message) is test-tool {
        subtest $message, :hidden, :instant, :!async, {
            plan 2;
            my ($result1, $result2) = (False, False);
            ...;
            ok $result1, "result1";
            ok $result2, "result2";
        }
    }

Note that we're using explicit C<:instant> and C<:!async> modes to prevent possible side effect related to use of
C<:parallel> and C<:random> in parent suite's plan. Besides, it is normal for a user to expect a test tool to be
semi-atomic operation being done here and now.

=head2 C<cmp-deeply(Mu \got, Mu \expected, Str:D $message)>

This test is similar to C<is-deeply> as it compares complex structure in depth. The difference is that C<cmp-deeply>
traverses deep into the structure is reports any difference found at the point where it is found. For example:

    my @got      = [1, 2, %( foo =>  Foo.new(:foo('13'), :fubar(11)) )];
    my @expected = [1, 2, %( foo =>  Foo.new(:foo(13),   :fubar(12)) )];

    cmp-deeply @got, @expected, "class instance deep withing an array";

This test would result in a diagnostic message like this:

    # Object at path [2]<foo>:
    #     expected $!foo: 13
    #                got: "13"
    #     expected $!fubar: 12
    #                  got: 11

Which tells us that a difference has been found in an instance of a class (I<Object>) located in a key C<foo> of an
L<C<Associative>|https://docs.raku.org/type/Associative> which is located in the second index of a L<C<Positional>|https://docs.raku.org/type/Positional>. Differences are reported for each
attribute where they are found.

Another difference of this test to C<is-deeply> is that it disrespect containerization status and focuses on structure
alone.

=head2 C<multi is-run(Str() $code, %params, Str:D $message = "")>
=head2 C<multi is-run(Str() $code, Str:D $message = "", *%params)>

This test tool is not provided by the standard L<C<Test>|https://docs.raku.org/type/Test> framework, but in slightly different forms it is defined
in helper modules included in
L<Rakudo|https://github.com/rakudo/rakudo/blob/e5ecdc4382d2739a701be7956fad52e897936fea/t/packages/Test/Helpers.pm6#L17>
and
L<roast|https://github.com/Raku/roast/blob/7033b07bbbb54a301b3bfd1253e30c5e7cebdfab/packages/Test-Helpers/lib/Test/Util.pm6#L107>
tests.

C<is-run> tests C<$code> by executing it in a child compiler process. In a way, it is like doing:

    # echo "$code" | rakudo -

Takes the following named parameters (C<%params> from the first candidate is passed to the second candidate as a
capture):

=item C<:$in> – data to be sent to the compiler input
=item C<:$out?> – expected standard output
=item C<:%env = %*ENV> - environment to be passed to the child process
=item C<:@compiler-args> – command line arguments for the compiler process
=item C<:@args> - command line arguments for C<$code>
=item C<:$err?> – expected error output
=item C<:$exitcode = 0> – expected process exit code.
=item C<:$timeout> - time in second to wait for the process to complete

=head2 C<multi test-flunks(Str:D $message, Bool :$remaining?)>
=head2 C<multi test-flunks($count)>
=head2 C<multi test-flunks(Str $message, $count)>

This test tool informs the bundle that the following tests are expected to flunk and this is exactly what we expect of
them to do! Or we can say that it inverts next C<$count> tests results. It can be considered as a meta-tool as it
operates over other test tools.

The primary purpose is to allow testing other test tools. For example, test I<t/080-is-approx.t> uses it to make sure
that tests are failing when they have to fail:

    test-flunks 2;
    is-approx 5, 6;
    is-approx 5, 6, 'test desc three';

Setting C<$count> to L<C<Inf>|https://docs.raku.org/type/Inf> is the same as using C<:remaining> named parameter and means: all remaining tests in the
current suite are expected to flunk.

=head1 SEE ALSO

L<C<Test::Async::Manual>|Manual.md>,
L<C<Test::Async::Decl>|Decl.md>,
L<C<Test::Async::Utils>|Utils.md>,
L<C<Test::Async::Event>|Event.md>

=AUTHOR Vadim Belman <vrurg@cpan.org>

=end pod

use Test::Async::Decl;

unit test-bundle Test::Async::Base;

use nqp;
use Test::Async::Utils;
use Test::Async::Hub;
use Test::Async::X;

use MONKEY-SEE-NO-EVAL;
use Test::Async::Event;

my class Event::Cmd::SetTestFlunk is Event::Command { }

has Str:D $.FLUNK-message = "";
has Numeric:D $.FLUNK-count = 0;
# If set then invoked when stage transitions into TSDismissed.
has &.dismiss-callback;
has &.fatality-callback;

# Helper class and sub for not attempting .gist or .raku when just a message is expected
my class _MSG {
    has $.msg;
    method raku { $!msg }
    method gist { $!msg }
}
my sub _msg(Str:D $msg) { _MSG.new(:$msg) }

method take-FLUNK {
    return Nil unless $!FLUNK-count;
    my $msg = $!FLUNK-message;
    $!FLUNK-message = "" unless --$!FLUNK-count;
    $msg
}

method pass(Str:D $message = "") is test-tool {
    self.proclaim: True, $message
}

method flunk(Str:D $message = "") is test-tool {
    self.proclaim: False, $message
}

method diag(**@msg) is test-tool(:!skip) {
    self.send: Event::Diag, :message(@msg.map(*.gist).join);
}

method ok(Mu $cond, Str:D $message = "") is test-tool {
    self.proclaim: $cond, $message
}

method nok(Mu $cond, Str:D $message = "") is test-tool {
    self.proclaim: !$cond, $message
}

proto method isa-ok(Mu, Mu, Str:D) is test-tool {*}
multi method isa-ok(Mu $got, Mu $expected, Str:D $message = "Is a '{$expected.^name}' type object") {
    self.proclaim:
        test-result(
            ($expected ~~ Str:D
                ?? $got.isa($expected)
                !! nqp::istype($got, $expected.WHAT)),
            fail => -> {
                comments => self.expected-got($expected.WHAT, $got.WHAT)
            }),
        $message
}

method can-ok(Mu $got, Str:D $meth,
              Str:D $message = ($got.defined ?? 'An object of ' !! 'The type ')
                                ~ $got.^name ~ " can do the method '$meth'"
) is test-tool {
    self.proclaim: $got.^can($meth), $message
}

method does-ok(Mu $got, Mu \type-object,
               Str:D $message = ($got.defined ?? 'An object of ' !! 'The type ')
                                 ~ $got.^name ~ " does role " ~ type-object.^name
) is test-tool {
    self.proclaim: $got.^does(type-object), $message
}

proto method is(|) is test-tool {*}
multi method is(Mu $got, Mu:U $expected, $message = "") {
    my $result;
    my $got-str;
    with $got {
        $result = False;
    }
    else {
        $result = nqp::if(
                    nqp::eqaddr($expected.WHAT, Mu),
                    nqp::eqaddr($got.WHAT, Mu),
                    nqp::if(
                        nqp::eqaddr($got.WHAT, Mu),
                        False,
                        $got === $expected));
    }
    self.proclaim:
            test-result($result,
                        fail => -> {
                            comments => self.expected-got($expected, $got, :gist)
                        }),
            $message;
}
multi method is(Mu $got, Mu:D $expected, $message = "") {
    my $result;
    my ($exp-str, $got-str);
    with $got {
        $result = nqp::if(
                    nqp::eqaddr($expected.WHAT, Mu),
                    nqp::eqaddr($got.WHAT, Mu),
                    nqp::if(
                        nqp::eqaddr($got.WHAT, Mu),
                        False,
                        ($got eq $expected)));
        unless $result {
            if try    $got     .Str.subst(/\s/, '', :g)
                   eq $expected.Str.subst(/\s/, '', :g)
            {
                # only white space differs, so better show it to the user
                $exp-str = $expected.raku;
                $got-str = $got.raku;
            }
            else {
                $exp-str = "'$expected'";
                $got-str = "'$got'";
            }
        }
    }
    else {
        $result = False;
        $exp-str = "'$expected'";
        $got-str = "({$got.^name})";
    }
    self.proclaim:
        test-result($result,
                    fail => -> {
                        comments => self.expected-got($exp-str, $got-str)
                    }),
        $message;
}

proto method isnt(|) is test-tool {*}
multi method isnt(Mu $got, Mu:U $expected, $message = "") {
    my $result;
    with $got {
        self.proclaim(True, $message);
        return;
    }
    $result = nqp::if(
                nqp::eqaddr($expected.WHAT, Mu),
                nqp::if(nqp::eqaddr($got.WHAT, Mu), False, True),
                nqp::if(
                    nqp::eqaddr($got.WHAT, Mu),
                    True,
                    $expected !=== $got));
    self.proclaim:
        test-result($result,
                    fail => -> {
                        comments => self.expected-got($expected, $got, :quote)
                    }),
        $message;
}

multi method isnt(Mu $got, Mu:D $expected, $message = "") {
    my $result;
    without $got {
        self.proclaim(True, $message);
        return;
    }
    $result = $got ne $expected;
    self.proclaim:
        test-result($result,
                    fail => -> {
                        comments => self.expected-got($expected, $got, :quote)
                    }),
        $message;
}

method cmp-ok(Mu $got is raw, $op, Mu $expected is raw, $message ='') is test-tool {
    my $result;
    my %ev-profile;
    # Defuse a Failure object
    $got.so if $got ~~ Failure;

    # the three labeled &CALLERS below are as follows:
    #  #1 handles ops that don't have '<' or '>'
    #  #2 handles ops that don't have '«' or '»'
    #  #3 handles all the rest by escaping '<' and '>' with backslashes.
    #     Note: #3 doesn't eliminate #1, as #3 fails with '<' operator
    my $matcher = nqp::istype($op, Callable) ?? $op
        !! &CALLERS::("infix:<$op>") #1
            // &CALLERS::("infix:«$op»") #2
            // &CALLERS::("infix:<$op.subst(/<?before <[<>]>>/, "\\", :g)>"); #3

    if $matcher {
        $result = test-result(
                    $matcher($got, $expected),
                    fail => -> {
                        comments => self.expected-got($expected.raku, $got.raku)
                                    ~ "\n matcher: " ~ ($matcher.?name || $matcher.^name)
                    });
    }
    else {
        $result =
            test-result(False,
                        fail => -> {
                            comments =>
                                ("Could not use '$op.raku()' as a comparator."
                                ~ (' If you are trying to use a meta operator, pass it as a ',
                                   "Callable instead of a string: \&[$op]"
                                        unless nqp::istype($op, Callable)))
                        });
    }
    self.proclaim: $result, $message;
}

method like(Str() $got, Regex:D $expected, Str $message = "text matches {$expected.raku}") is test-tool {
    self.proclaim:
        test-result(
            $got ~~ $expected,
            fail => -> {
                comments => self.expected-got($expected, $got, :exp-sfx('a match with'))
            }
        ),
        $message
}

method unlike(Str() $got, Regex:D $expected, Str $message = "text matches {$expected.raku}") is test-tool {
    self.proclaim:
        test-result(
            ! ($got ~~ $expected),
            fail => -> {
                comments => self.expected-got($expected, $got, :exp-sfx("no match with"))
            }
        ),
        $message
}

method use-ok(Str:D $code, Str:D $message = "'$code' can be use-d") is test-tool {
    try {
        EVAL "use $code";
    }
    self.proclaim:
        test-result(
            (! $!.defined),
            fail => {
                comments => ($! ?? ~$! !! Empty),
            }
        ),
        $message
}

method dies-ok(Callable $code, Str:D $message = "code anticipated to die") is test-tool {
    my $dies = True;
    try {
        $code();
        $dies = False;
    }

    self.proclaim: $dies, $message;
}

method lives-ok(Callable $code, Str:D $message = "code anticipated to die") is test-tool {
    my $lives = False;
    try {
        $code();
        $lives = True;
    }

    self.proclaim:
        test-result(
            $lives,
            fail => -> {
                comments => ($! ?? "Error: " ~ $! !! Empty),
            }
        ),
        $message;
}

method !eval-exception($code, $context) {
    try { EVAL $code, :$context }
    $!
}

method eval-dies-ok(Str() $code, Str:D $message = "EVAL'ed code anticipated to die") is test-tool {
    my $context = $.tool-caller.stash // CALLER::;
    my $ex = self!eval-exception($code, $context);
    self.proclaim: $ex.defined, $message;
}

method eval-lives-ok(Str() $code, Str:D $message = "EVAL'ed code anticipated to die") is test-tool {
    my $context = $.tool-caller.stash // CALLER::;
    my $ex = self!eval-exception($code, $context);
    self.proclaim:
        test-result(
            !$ex.defined,
            fail => -> {
                comments => ($ex ?? "Error: " ~ $ex !! Empty),
            }
        ), $message;
}

method !validate-matchers(%matcher) {
    for %matcher.kv -> $k, $v {
        if $v.DEFINITE && $v ~~ Bool {
            X::Match::Bool.new(:type(".$k")).throw;
        }
    }
}

method throws-like($code where Callable:D | Str:D, $ex_type, Str:D $message = "did we throws-like $ex_type.^name()?", *%matcher) is test-tool {
    self!validate-matchers(%matcher);
    # Don't guess our caller context, know it!
    my $caller-context = $.tool-caller.stash // CALLER::;
    my $rc = False;
    self.subtest: $message, :instant, :hidden, :!async, {
        my \suite = self.test-suite;
        suite.plan: 2 + %matcher.keys.elems;
        my $msg;
        if $code ~~ Callable {
            $msg = 'code dies';
            $code()
        } else {
            $msg = "'$code' died";
            EVAL $code, context => $caller-context;
        }
        suite.flunk: $msg;
        suite.skip-rest: 'Code did not die, can not check exception'; #, 1 + %matcher.elems;
        CATCH {
            default {
                suite.pass: $msg;
                $rc = True;
                my $type_ok = $_ ~~ $ex_type;
                if $type_ok {
                    suite.pass: "right exception type ($ex_type.^name())";
                    for %matcher.kv -> $k, $v {
                        my $got is default(Nil) = $_."$k"();
                        my $ok = $got ~~ $v;
                        $rc &&= $ok;
                        suite.proclaim:
                            test-result(
                                $ok,
                                fail => -> { comments => self.expected-got($v, $got) }
                            ),
                            ".$k " ~ ($v ~~ Code ?? "passes validation" !! "matches " ~ $v.gist())
                    }
                } else {
                    suite.send-test(
                        Event::NotOk,
                        'wrong exception type',
                        TRFailed,
                        comments => (self.expected-got($ex_type.^name, $_.^name),
                                     "Exception message: " ~ .message)
                    );
                    suite.skip-rest: 'wrong exception type';
                }
            }
        }
    };
    $rc
}

method fails-like (
    $code where Callable:D | Str:D, $ex-type, Str:D $message = "did we fails-like $ex-type.^name()?", *%matcher
) is test-tool {
    self!validate-matchers(%matcher);
    my $throws-like-context = $.tool-caller.stash // CALLER::;
    my $rc = False;
    self.subtest: $message, :instant, :hidden, :!async, -> \suite {
        suite.plan: 2;
        CATCH { default {
            with "expected code to fail but it threw {.^name} instead" {
                suite.flunk: $_;
                suite.skip: $_;
            }
        }}
        my $res = $code ~~ Callable ?? $code() !! $code.EVAL;
        $rc = suite.isa-ok: $res, Failure, 'code returned a Failure';
        $rc &&= suite.throws-like:
            { $res.sink },
            $ex-type,
            'Failure threw when sunk',
            |%matcher;
    };
    $rc
}

method is-approx-calculate(
    $got,
    $expected,
    $abs-tol where { !.defined or $_ >= 0 },
    $rel-tol where { !.defined or $_ >= 0 },
    Str:D $message = ""
) is test-tool
{
    my Bool    ($abs-tol-ok, $rel-tol-ok) = True, True;
    my Numeric ($abs-tol-got, $rel-tol-got);
    with $abs-tol {
        $abs-tol-got = abs($got - $expected);
        $abs-tol-ok = $abs-tol-got <= $abs-tol;
    }
    with $rel-tol {
        if max($got.abs, $expected.abs) -> $max {
            $rel-tol-got = abs($got - $expected) / $max;
            $rel-tol-ok = $rel-tol-got <= $rel-tol;
        }
        else {
            # if $max is zero, then both $got and $expected are zero
            # and so our relative difference is also zero
            $rel-tol-got = 0;
        }
    }

    my $result = test-result(
                    $abs-tol-ok && $rel-tol-ok,
                    fail => -> {
                        "comments" => (
                              "    expected approximately: $expected\n"
                            ~ "                       got: $got",
                            $abs-tol-ok
                            ?? Empty
                            !!   "maximum absolute tolerance: $abs-tol\n"
                               ~ "actual absolute difference: $abs-tol-got",
                            $rel-tol-ok
                            ?? Empty
                            !!   "maximum relative tolerance: $rel-tol\n"
                               ~ "actual relative difference: $rel-tol-got"
                        ),
                    }
    );
    # note "RESULT? ", $result.fail-profile.raku;
    self.proclaim($result, $message);
}

# We're picking and choosing which tolerance to use here, to make it easier
# to test numbers close to zero, yet maintain relative tolerance elsewhere.
# For example, relative tolerance works equally well with regular and huge,
# but once we go down to zero, things break down: is-approx sin(τ), 0; would
# fail, because the computed relative tolerance is 1. For such cases, absolute
# tolerance is better suited, so we DWIM in the no-tol version of the sub.
proto method is-approx(|) is test-tool {*}
multi method is-approx(Numeric $got, Numeric $expected, $desc = '') {
    $expected.abs < 1e-6
        ?? self.is-approx-calculate($got, $expected, 1e-5, Nil, $desc) # abs-tol
        !! self.is-approx-calculate($got, $expected, Nil, 1e-6, $desc) # rel-tol
}

multi method is-approx(
    Numeric $got, Numeric $expected, Numeric $abs-tol, $desc = ''
) {
    self.is-approx-calculate($got, $expected, $abs-tol, Nil, $desc);
}

multi method is-approx(
    Numeric $got, Numeric $expected, $desc = '',
    Numeric :$rel-tol is required, Numeric :$abs-tol is required
) {
    self.is-approx-calculate($got, $expected, $abs-tol, $rel-tol, $desc);
}

multi method is-approx(
    Numeric $got, Numeric $expected, $desc = '', Numeric :$rel-tol is required
) {
    self.is-approx-calculate($got, $expected, Nil, $rel-tol, $desc);
}

multi method is-approx(
    Numeric $got, Numeric $expected, $desc = '', Numeric :$abs-tol is required
) {
    self.is-approx-calculate($got, $expected, $abs-tol, Nil, $desc);
}

proto method is-deeply(|) is test-tool {*}
multi method is-deeply(Seq:D $got, Seq:D $expected, $message = '') {
    self.is-deeply: $got.cache, $expected.cache, $message;
}
multi method is-deeply(Seq:D $got, Mu $expected, $message = '') {
    self.is-deeply: $got.cache, $expected, $message;
}
multi method is-deeply(Mu $got, Seq:D $expected, $message = '') {
    self.is-deeply: $got, $expected.cache, $message;
}
multi method is-deeply(Mu $got, Mu $expected, $message = '') {
    my $result = test-result
                    $got eqv $expected,
                    fail => -> {
                        comments => self.expected-got($expected, $got),
                    };
    self.proclaim($result, $message)
}

method cmp-deeply(Mu \got, Mu \expected, $message = '') is test-tool {
    my subset Simple of Mu where Stringy | Numeric | Junction;

    my sub cmp-simple(Mu $val1, Mu $val2) {
        ($val1.WHAT & $val2.WHAT) ~~ Stringy | Numeric
            && $val1.WHAT ~~ $val2.WHAT
            ?? $val1 eqv $val2
            !! $val1.raku eq $val2.raku
    }

    my proto sub deep-cmp(|) {*}

    multi sub deep-cmp(Junction:D $val1, Junction:D $val2, Str:D $path) {
        unless $val1.raku eq $val2.raku {
            take ("Junction", $path, (($val1, $val2),));
        }
    }

    multi sub deep-cmp(Seq:D $val1, Seq:D $val2, Str:D $path) {
        deep-cmp $val1.List, $val2.List, $path, :what<Sequence>
    }

    multi sub deep-cmp(%v1, %v2, Str:D $path) {
        my @diffs;

        unless %v1.keys (==) %v2.keys {
            my $all-keys = %v1.keys ∪ %v2.keys;
            my sub key-list(%h) {
                _msg( $all-keys.keys.sort.map({ %h{$_}:exists ?? "<$_>" !! (' ' x (.chars + 2)) }).join(" ") )
            }
            @diffs.push: (key-list(%v1), key-list(%v2), :exp-sfx<keys>, :got-sfx<keys>);
        }

        for (%v1.keys ∪ %v2.keys).keys.sort -> $key {
            my $exp-sfx = "at key <$key>";
            my $v1k := %v1{$key};
            my $v2k := %v2{$key};
            my $both-val = $v1k & $v2k;

            if %v1{$key}:!exists {
                @diffs.push: (_msg("no key"), %v2{$key}, :$exp-sfx);
            }
            elsif %v2{$key}:!exists {
                @diffs.push: (%v1{$key}, "no key", :$exp-sfx);
            }
            elsif !$both-val.defined {
                @diffs.push: ($v1k, $v2k, :$exp-sfx, :gist) unless $v1k === $v2k;
            }
            elsif $both-val ~~ Simple {
                @diffs.push: ($v1k, $v2k, :$exp-sfx) unless cmp-simple($v1k, $v2k);
            }
            else {
                deep-cmp(%v1{$key}<>, %v2{$key}<>, $path ~ "<$key>");
            }
        }
        take (%v1.^name, $path, @diffs) if @diffs;
    }

    multi sub deep-cmp(List:D $val1, List:D $val2, Str:D $path, Str :$what) {
        my @diffs;

        if $val1.elems != $val2.elems {
            @diffs.push: ($val1.elems, $val2.elems, :exp-sfx<size>, :got-sfx<size>);
        }

        for ^($val1.elems max $val2.elems) -> $idx {
            next if !(($val1[$idx]:exists) || ($val2[$idx]:exists));

            my $v1idx := $val1[$idx];
            my $v2idx := $val2[$idx];
            my $both-val := $v1idx & $v2idx;
            my $exp-sfx = "at [$idx]";

            if $val1[$idx]:!exists {
                @diffs.push: (_msg("no element"), $val2[$idx], :$exp-sfx);
            }
            elsif $val2[$idx]:!exists {
                @diffs.push: ($val1[$idx], _msg("no element"), :$exp-sfx);
            }
            elsif !$both-val.defined {
                @diffs.push: ($v1idx, $v2idx, :$exp-sfx, :gist) unless $v1idx === $v2idx;
            }
            elsif $both-val ~~ Simple {
                @diffs.push: ($v1idx, $v2idx, :$exp-sfx) unless cmp-simple($v1idx, $v2idx);
            }
            else {
                deep-cmp($val1[$idx], $val2[$idx], $path ~ "[$idx]");
            }
        }
        take (($what // $val1.^name), $path, @diffs) if @diffs;
    }

    multi sub deep-cmp(&v1, &v2, Str:D $path) {
        unless &v1 === &v2 {
            take (&v1.^name, $path, ((&v1, &v2),));
        }
    }

    multi sub deep-cmp(QuantHash:D $val1, QuantHash:D $val2, Str:D $path) {
        unless $val1.WHAT =:= $val2.WHAT && $val1 == $val2 {
            take ($val1.^name, $path, (($val1, $val2),));
        }
    }

    multi sub deep-cmp(Numeric:D $val1, Numeric:D $val2, Str:D $path) {
        unless $val1 == $val2 {
            take ("Numeric", $path, (($val1, $val2),));
        }
    }

    multi sub deep-cmp(Stringy:D $val1, Stringy:D $val2, Str:D $path) {
        unless $val1 eq $val2 {
            take ("String", $path, (($val1, $val2),));
        }
    }

    multi sub deep-cmp(Mu:D $val1, Mu:D $val2, Str:D $path) {
        my @diffs;
        if $val1.WHAT =:= $val2.WHAT {
            for $val1.WHAT.^attributes(:all, :!local) -> $attr {
                next unless $attr.has_accessor || $attr.is_built;
                my $v1a := $attr.get_value($val1);
                my $v2a := $attr.get_value($val2);
                my $both-val = $v1a & $v2a;
                my $exp-sfx = $attr.name;
                if $both-val.defined {
                    if $both-val ~~ Simple {
                        @diffs.push: ($v1a, $v2a, :$exp-sfx) unless cmp-simple($v1a, $v2a);
                    }
                    else {
                        deep-cmp $v1a, $v2a, $path ~ ($attr.has_accessor ?? "." !! "!")  ~ $attr.name.substr(2);
                    }
                }
                elsif !$v1a.defined {
                    @diffs.push: (_msg("type object of " ~ $v1a.^name), $v2a, :$exp-sfx);
                }
                else {
                    @diffs.push: ($v1a, _msg("type object of " ~ $v2a.^name), :$exp-sfx);
                }
            }
        }
        else {
            @diffs.push: ($val1, $val2);
        }
        take ("Object", $path, @diffs) if @diffs;
    }

    multi sub deep-cmp(Mu:U $val1, Mu:D $val2, Str:D $path) {
        take ("Object", $path, ((_msg("type object of " ~ $val1.^name), $val2),));
    }

    multi sub deep-cmp(Mu:D $val1, Mu:U $val2, Str:D $path) {
        take ("Object", $path, (($val1, _msg("type object of " ~ $val2.^name)),));
    }

    multi sub deep-cmp(Mu:U $val1, Mu:U $val2, Str:D $path) {
        take ("Type object", $path, (($val1, $val2, :gist),)) unless $val1 === $val2;
    }

    my @diffs = gather deep-cmp(expected, got, "");
    my $result = test-result
        !@diffs,
        fail => -> {
            comments => @diffs.map: {
                # Each diff is [$what, $path, [(got, expected), ...]]
                .[0] ~ |(" at path " ~ .[1] if .[1]) ~ ":\n" ~
                .[2].map({ self.expected-got(| .Capture).indent(4) }).join("\n")
            }
        };

    self.proclaim: $result, $message
}

method skip(Str:D $message = "", UInt:D $count = 1) is test-tool(:!skippable) {
    for ^$count {
        self.send-test: Event::Skip, $message, TRSkipped
    }
    True
}

method skip-rest(Str:D $message = "") is test-tool(:!skippable) {
    with self.planned {
        self.skip($message, self.planned - $.tests-run);
    }
    else {
        self.throw: Test::Async::X::PlanRequired, :op<skip-rest>
    }
}

method skip-remaining(Str:D $message = "", Bool :$global?) is test-tool(:!skippable) {
    self.send-command: Event::Cmd::SkipRemaining, $message;
    if $global {
        .skip-remaining: $message, :$global with $.parent-suite;
    }
    # Make sure no other test tool is ran in our thread until skipping gets into effect.
    self.sync-events;
}

method todo(Str:D $message, UInt:D $count = 1) is test-tool(:!skippable) {
    self.set-todo($message, $count);
    self.sync-events;
}

method todo-remaining(Str:D $message) is test-tool(:!skippable) {
    self.set-todo($message, Inf);
    self.sync-events;
}

method bail-out(Str:D $message = "") is test-tool(:!skippable) {
    self.send: Event::BailOut, :$message;
    self.sync-events;
    self.fatality;
    exit 255;
}

proto method subtest(|) is test-tool(:!wrap) {*}
multi method subtest(Pair:D $subtest (Str(Any:D) :key($message), :value(&code)), *%plan) is hidden-from-backtrace {
    self.subtest(&code, $message, |%plan);
}
multi method subtest(Str:D $message, Callable:D \subtests, *%plan) is hidden-from-backtrace {
    self.subtest(subtests, $message, |%plan)
}
multi method subtest( Callable:D \subtests,
                      Str:D $message,
                      Bool:D :$async = False,
                      Bool:D :$instant = False,
                      Bool:D :$hidden = False,
                      *%plan ) is hidden-from-backtrace
{
    my $subtest-ctx = self.locate-tool-caller(1);

    if self.stage >= TSFinished {
        warn "A subtest found after done-testing at " ~ $subtest-ctx.frame.gist;
        return;
    }
    self.set-stage(TSInProgress);
    if $.skip-message.defined {
        self.send-test: Event::Skip, $.skip-message, TRSkipped;
        return True
    }

    my $flunk-msg = self.take-FLUNK;

    my sub send-proclaim($subtest, Bool:D $cond, %profile) {
        my %ev-profile = |%profile, :caller($subtest.suite-caller);
        if $subtest.messages.elems {
            %ev-profile<child-messages> := $subtest.messages<>;
        }
        unless $subtest.transparent {
            %ev-profile<pre-comments> := ["Subtest: " ~ $subtest.message ];
        }
        self.proclaim($cond, $message, %ev-profile, :bypass-todo);
    }

    my sub finalize-subtest($subtest) {
        CATCH {
            default {
                # self.trace-out: "! Finalization died with ", .^name, ":\n", .message, "\n", .backtrace.Str;
                self.x-sorry: $_, :comment("Finalization block died");
                .rethrow
            }
        }
        my %ev-profile = |(:todo($_) with $subtest.is-TODO);
        # Signal to send-test method that this suite has been marked as flunky.
        my $*TEST-FLUNK-SAVE = $flunk-msg;
        send-proclaim( $subtest,
                       (!$subtest.tests-failed && (!$subtest.planned || $subtest.planned == $subtest.tests-run)),
                       %ev-profile);
    };

    my sub finalize-on-exception($subtest, :$exception, :$event-queue) {
        # Only process test body generated exceptions, skip if the event loop thread thrown or event queue is closed
        # for one reason or another.
        return False unless $exception && !$event-queue && $subtest.event-queue-is-active;
        CATCH {
            default {
                self.x-sorry: $_, :comment("Fatality callback died");
                .rethrow
            }
        }
        # When reacting to a fatal termination TODO and flunk statuses must be ignored because they must only be
        # respected for non-passing test, not for dying ones.
        $subtest.send: Event::Diag,  message => "===SORRY!=== Subtest died with "
                                                              ~ $exception.^name ~ ":\n"
                                                              ~ ($exception.message ~ "\n"
                                                              ~ $exception.backtrace).indent(2);
        $subtest.sync-events;
        send-proclaim($subtest, False, %());
        True
    }

    my %profile = :code(subtests),
                  :$message,
                  :dismiss-callback(&finalize-subtest),
                  :fatality-callback(&finalize-on-exception),
                  :transparent($hidden);
    # Provide the child suite with right context.
    self.push-tool-caller: $subtest-ctx unless $hidden;
    my $child = self.create-suite: |%profile, :subtest-report;
    $child.plan: |%plan if %plan;
    # Remove tool call entry from the stack because the child suite already has it and it might be run asynchronously or
    # randomly.
    self.pop-tool-caller unless $hidden;

    self.invoke-suite( $child, :$async, :$instant, args => \($child) );
}

proto method is-run(|) is test-tool {*}
multi method is-run(Str:D() $code, %expected, Str:D $message = "") {
    self.is-run: $code, $message, |%expected
}
multi method is-run (
    Str:D() $code, Str:D $message = "",
    Stringy :$in, :@compiler-args, :@args, :%env = %*ENV, :$out?, :$err?, :$exitcode = 0, :$async = False,
    UInt :$timeout )
{
    self.subtest: $message, :instant, :hidden, :$async, -> $suite {
        $suite.plan(1 + ?$out.defined + ?$err.defined);
        my $code-file = self.temp-file('code', $code);
        LEAVE $code-file.IO.unlink;

        my @proc-args = $*EXECUTABLE, |@compiler-args, $code-file, |@args;

        my $proc = Proc::Async.new: @proc-args;

        my $proc-out = "";
        my $proc-err = "";
        my $proc-exitcode;
        my $timed-out = False;
        my $in-method = $in ~~ Blob ?? "write" !! "print";

        react {
            whenever $proc.stdout {
                $proc-out ~= $_;
            }
            whenever $proc.stderr {
                $proc-err ~= $_;
            }
            whenever $proc.start(ENV => %env) {
                $proc-exitcode = .exitcode;
                done;
            }
            with $in {
                whenever $proc."$in-method"($in) {
                    $proc.close-stdin;
                }
            }
            with $timeout {
                whenever Promise.in($timeout) {
                    $timed-out = True;
                    $proc.kill: SIGKILL;
                }
            }
        }

        if $timed-out {
            $suite.flunk: "code timed out";
        }
        else {
            my $wanted-exitcode = $exitcode // 0;

            given $suite {
                .cmp-ok: $proc-out, '~~', $out, 'STDOUT' if $out.defined;
                .cmp-ok: $proc-err, '~~', $err, 'STDERR' if $err.defined;
                .cmp-ok: $proc-exitcode, '~~', $wanted-exitcode, 'Exit code';
            }
        }
    }
}

method cmd-settestflunk(Str:D $message, Numeric:D $count) {
    $!FLUNK-message = $message;
    $!FLUNK-count = $count;
}

method !set-FLUNK($message, $count) {
    self.send-command: Event::Cmd::SetTestFlunk, $message, $count;
    self.sync-events;
}

my constant TEST-FLUNK-MSG = 'anticipated test failure';
proto method test-flunks(|) is test-tool(:!skippable) {*}
multi method test-flunks(Str:D $message = TEST-FLUNK-MSG, :$remaining! where *.so) {
    self!set-FLUNK(TEST-FLUNK-MSG, Inf)
}
multi method test-flunks(Inf) {
    self!set-FLUNK(TEST-FLUNK-MSG, Inf)
}
multi method test-flunks(Int:D $count where * > 0 = 1) {
    self!set-FLUNK(TEST-FLUNK-MSG, $count)
}
multi method test-flunks(Str:D $message, Inf) {
    self!set-FLUNK($message, Inf)
}
multi method test-flunks(Str:D $message = TEST-FLUNK-MSG, Int:D $count where * > 0 = 1) {
    self!set-FLUNK($message, $count)
}

proto method expected-got(Mu, Mu, |) {*}
multi method expected-got(Str:D $expected, Str:D $got, Str :$exp-sfx, Str :$got-sfx) {
    my $exp-str = "expected" ~ ($exp-sfx ?? " $exp-sfx" !! "");
    my $got-str = "got" ~ ($got-sfx ?? " $got-sfx" !! "");
    my $flen = max $exp-str.chars, $got-str.chars;
    my $format = "%" ~ $flen ~ "s: ";
      $exp-str.fmt($format) ~ $expected ~ "\n"
    ~ $got-str.fmt($format) ~ $got
}
multi method expected-got(+@pos where *.elems == 2, :$gist, :$quote, *%c) {
    my @stringified;
    for @pos -> $pos {
        my $spos;
        if $gist && nqp::can($pos, 'gist') {
            $spos = try $pos.gist;
        }
        unless $spos {
            $spos = stringify($pos);
            $spos = "'$spos'" if $quote;
        }
        @stringified.push: $spos;
    }
    self.expected-got: |@stringified, |%c;
}

# Wrap the default method to invert test result when test-flunks is in effect.
multi method send-test(::?CLASS:D: Event::Test:U \evType, Str:D $message, TestResult:D $tr, *%profile) {
    self.send-test: evType, $message, $tr, %profile;
}
multi method send-test(::?CLASS:D: Event::Test:U \evType, Str:D $message, TestResult:D $tr, %ev-profile, *%c) {
    with (my $fmsg = $*TEST-FLUNK-SAVE // self.take-FLUNK) {
        my %profile = %ev-profile;
        my sub fail-message($reason) {
              "NOT FLUNK: $fmsg\n"
            ~ "    Cause: Test $reason"
        }
        my $evType := evType;
        my $test-result;
        my @comments = (%profile<comments> //= []).List;
        given evType {
            when Event::NotOk {
                @comments.unshift: 'FLUNK - ' ~ $fmsg;
                $evType := Event::Ok;
                $test-result = TRPassed;
            }
            when Event::Ok {
                @comments.unshift: fail-message('passed');
                $evType := Event::NotOk;
                $test-result = TRFailed;
            }
            # skips are ok to ignore
            when Event::Skip { $test-result = $tr; }
            # This would catch any custom event from a 3rd party bundle.
            default {
                @comments.unshift: fail-message('resulted in unknown ' ~ evType.^name ~ " event");
                $evType := Event::NotOk;
                $test-result = TRFailed;
            }
        }
        %profile<comments> = @comments;
        callwith($evType, $message, $test-result, %profile, |%c);
    }
    else {
        callsame
    }
    # say "RETURN($message):", $tr == TRPassed;
    $tr == TRPassed
}

multi method event(::?CLASS:D: Event::StageTransition:D $ev) {
    if &!dismiss-callback && $ev.to == TSDismissed {
        &!dismiss-callback(self);
    }
    nextsame
}

method fatality($?, *%p) {
    if &!fatality-callback {
        return if &!fatality-callback(self, |%p);
    }
    nextsame
}