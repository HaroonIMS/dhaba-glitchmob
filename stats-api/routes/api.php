<?php

use App\Http\Controllers\StatsController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => response()->json(['status' => 'ok']));
Route::get('/info', [StatsController::class, 'info']);
Route::get('/api/stats/info', [StatsController::class, 'info']); // reachable through the ingress
Route::get('/api/stats', [StatsController::class, 'stats']);
