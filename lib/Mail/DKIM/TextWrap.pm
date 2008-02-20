#!/usr/bin/perl

use strict;
use warnings;

package Mail::DKIM::TextWrap;
use Carp;

sub new
{
	my $class = shift;
	my %args = @_;
	my $self = {
		Margin => 72,
		Break => qr/\s/,
		BreakBefore => undef,
		Swallow => qr/\s/,
		Separator => "\n",
		cur => 0,
		soft_space => "",
		%args,
	};
	$self->{Output} ||= \*STDOUT;
	return bless $self, $class;
}

sub _calculate_new_column
{
	my ($cur, $text) = @_;
	confess "invalid argument" unless defined($text);

	while ($text =~ /^(.*?)([\n\r\t])(.*)$/s)
	{
		$cur += length($1);
		if ($2 eq "\t")
		{
			$cur = (int($cur / 8) + 1) * 8;
		}
		else
		{
			$cur = 0;
		}
		$text = $3;
	}
	$cur += length($text);
	return $cur;
}

sub add
{
	my ($self, $text) = @_;
	my $break_after = $self->{Break};
	my $break_before = $self->{BreakBefore};
	my $swallow = $self->{Swallow};
	while (length $text)
	{
		my ($word, $remaining);
		if (defined($break_before) and $text =~ /^(.+?)($break_before)(.*)$/s)
		{
			# note- $1 should have at least one character
			$word = $1;
			$remaining = $2 . $3;
		}
		elsif (defined($break_after) and $text =~ /^(.*?)($break_after)(.*)$/s)
		{
			$word = $1 . $2;
			$remaining = $3;
		}
		else
		{
			$word = $text;
			$remaining = "";
		}

		my $next_soft_space;
		if ($word =~ /^(.*)($swallow)$/s)
		{
			$word = $1;
			$next_soft_space = $2;
		}
		else
		{
			$next_soft_space = "";
		}

# cur - the last known column position
#
# soft_space - contains added text that will not be printed if a linebreak
#              occurs
#
		my $to_print = $self->{soft_space} . $word;
		my $new_pos = _calculate_new_column($self->{cur}, $to_print);

		if ($new_pos > $self->{Margin})
		{
			# what would happen if we put the separator in?
			my $w_sep = _calculate_new_column($self->{cur},
					$self->{Separator});
			if ($w_sep < $self->{cur})
			{
				# inserting the separator gives us more room,
				# so do it
				$self->output($self->{Separator});
				$self->{soft_space} = "";
				$self->{cur} = $w_sep;
				next;
			}
		}

		$self->output($to_print);
		$self->{soft_space} = $next_soft_space;
		$self->{cur} = $new_pos;
		$text = $remaining;
	}
}

sub finish
{
	my $self = shift;
	$self->output($self->{soft_space});
	$self->reset;
}

sub output
{
	my $self = shift;
	my $to_print = shift;

	my $out = $self->{Output};
	if (UNIVERSAL::isa($out, "GLOB"))
	{
		print $out $to_print;
	}
	elsif (UNIVERSAL::isa($out, "SCALAR"))
	{
		$$out .= $to_print;
	}
}

sub reset
{
	my $self = shift;
	$self->{cur} = 0;
	$self->{soft_space} = "";
}

1;
