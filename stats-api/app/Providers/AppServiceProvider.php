<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        // orders-api writes keys without a prefix, so Laravel must not add one.
        config(['database.redis.options.prefix' => '']);
    }
}
