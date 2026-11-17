<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Redis;

class StatsController extends Controller
{
    public function info(): JsonResponse
    {
        return response()->json([
            'version' => getenv('GIT_COMMIT') ?: 'dev',
            'pod' => gethostname(),
        ]);
    }

    public function stats(): JsonResponse
    {
        try {
            $minute = intdiv(time(), 60);
            $counts = [];
            for ($i = 0; $i < 5; $i++) {
                // orders-api increments stats:orders:<minute> for every order
                $counts[] = (int) Redis::get('stats:orders:'.($minute - $i));
            }
            $dishes = Redis::zrevrange('stats:dishes', 0, 4, ['withscores' => true]);
        } catch (\Exception $e) {
            return response()->json(['error' => 'stats are unavailable'], 503);
        }

        $top = [];
        foreach ((array) $dishes as $name => $score) {
            $top[] = ['name' => (string) $name, 'count' => (int) $score];
        }

        return response()->json([
            'orders_this_minute' => $counts[0],
            'orders_last_5_minutes' => array_sum($counts),
            'top_dishes' => $top,
        ]);
    }
}
