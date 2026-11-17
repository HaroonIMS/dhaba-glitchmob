<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Redis;
use Tests\TestCase;

class StatsTest extends TestCase
{
    public function test_health_is_ok(): void
    {
        $this->getJson('/health')->assertOk()->assertJson(['status' => 'ok']);
    }

    public function test_info_shows_version_and_pod(): void
    {
        $this->getJson('/api/stats/info')->assertOk()->assertJsonStructure(['version', 'pod']);
    }

    public function test_stats_are_read_from_redis(): void
    {
        Redis::shouldReceive('get')->andReturn('2');
        Redis::shouldReceive('zrevrange')->andReturn(['Biryani' => '5', 'Naan' => '3']);

        $this->getJson('/api/stats')->assertOk()->assertExactJson([
            'orders_this_minute' => 2,
            'orders_last_5_minutes' => 10,
            'top_dishes' => [
                ['name' => 'Biryani', 'count' => 5],
                ['name' => 'Naan', 'count' => 3],
            ],
        ]);
    }

    public function test_stats_return_503_when_redis_is_down(): void
    {
        Redis::shouldReceive('get')->andThrow(new \RuntimeException('connection refused'));

        $this->getJson('/api/stats')->assertStatus(503);
    }
}
