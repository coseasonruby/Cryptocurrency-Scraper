package Exchange::Liqui;
use strict;
use warnings;

use parent 'Exchange';

use Data::Dumper;
use Try::Tiny;

sub _init {
  my $self = shift;
  $self->{config} = {
      'id' => 'liqui',
            'name' => 'Liqui',
            'countries' => 'UA', 
            'rateLimit' => 100, # per 15 minutes
            'base_currency' => 'UAH',
            'has' => {
                'CORS' => 1,
                'fetchTickers' => 1,
                'withdraw' => 1,
            },
            'urls' => {
                'logo' => 'https://liqui.io/img/logo.svg',
                'api' => 'https://api.liqui.io/api/',
                'www' => 'https://liqui.io/',
                'doc' => 'https://liqui.io/api',
            },
            'can' => {
              'rest'  => 1,
              'push'  => undef,
              'wsock' => undef,
            },
            'fees' => {
                'trading' => {
                    'maker' => 0.1 / 100,
                    'taker' => 0.25 / 100,
                },
            },
        'symbols' => $self->_get_symbols()
    },
}

sub ticker {
  my $self = shift;
  my %vars = @_;

  foreach my $symbol (@{$self->{config}->{symbols}}) {
    next if !defined $symbol->{id};

    $self->get(
      url => "https://api.liqui.io/api/3/ticker/$symbol->{id}",
      on_result => sub { $self->process_ticker(@_, undef, id => $symbol->{id}) },
      on_error  => sub { $self->common_error(@_) },
    );
  }

}

sub process_ticker {
  my $self = shift;
  my $tx = shift;
  my ($tp1, $tp2, $curr) = (@_);

  my $currency    = $tx->result->json->{$curr};

  $self->store_ticker(
      source    => $self->config->{id},
      currency    => $curr,
      status    => 0, # proper status for the ticker w/o errors
      date_ts   => $currency->{updated},
      base_currency   => $self->config->{base_currency},
      base_usd_rate => $self->usd_rates->{$self->config->{base_currency}}//1,
      highest_bid => $currency->{buy},
      lowest_ask  => $currency->{sell},
      opening_price => 0,
      closing_price => $currency->{last}, 
      min_price   => $currency->{low},
      max_price   => $currency->{high},
      average_price => $currency->{avg},
      units_traded  => 0,
      volume_1day => $currency->{vol_cur},
      volume_7day => 0, 
    );

  return 1;
}

sub _get_symbols {
  my $self = shift;
  my $result = $self->ua->get('https://api.liqui.io/api/3/info')->result->json->{pairs};
  my $new_result;
  
  foreach (keys %{$result}) { # should be always named 'id' for using in loops
    next unless $self->symbol_allowed($_) || $self->symbol_allowed('t'.$_);
    push @{$new_result}, {id => $_};
  }

  return $new_result;
}

2;