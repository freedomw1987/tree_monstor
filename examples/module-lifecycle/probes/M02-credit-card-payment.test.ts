/**
 * M02-credit-card-payment 探針範例
 *
 * 本檔為範例，展示 regression-guard v2.10 的探針格式：
 * - 探針名稱必含 Module prefix（`M02-`）
 * - 跑時用 `REGRESSION_MODULE=M02 ./run_pipeline.sh` 限定 Module 範圍
 *
 * 對應 skill：`regression-guard`（v2.10 加 Module prefix 規則）
 * 對應模組：M02-payment
 */

import { probe, describe } from 'regression-guard';

describe('M02-credit-card-payment', () => {

  probe('M02-create-payment-returns-success-on-valid-card', async () => {
    // Arrange
    const input = {
      orderId: 'ORDER-123',
      amount: 1000,
      cardNumber: '4242424242424242', // Stripe 測試卡號
    };

    // Act
    const payment = await paymentService.createPayment(input);

    // Assert
    return {
      actual: payment.status,
      expected: 'PENDING',
    };
  });

  probe('M02-create-payment-fails-on-invalid-card', async () => {
    // Arrange
    const input = {
      orderId: 'ORDER-124',
      amount: 1000,
      cardNumber: '4000000000000002', // Stripe 拒絕卡號
    };

    // Act + Assert
    try {
      await paymentService.createPayment(input);
      throw new Error('應該 reject 但沒有');
    } catch (err) {
      return {
        actual: err.code,
        expected: 'PAYMENT_001',
      };
    }
  });

  probe('M02-payment-timeout-releases-db-connection', async () => {
    // Arrange: 模擬第三方閘道 timeout
    jest.useFakeTimers();
    const slowGateway = new SlowStripeAdapter({ delayMs: 31000 });

    // Act
    const promise = paymentService.createPayment({
      orderId: 'ORDER-125',
      amount: 1000,
      cardNumber: '4242424242424242',
    }, slowGateway);

    jest.advanceTimersByTime(31000);
    await expect(promise).rejects.toThrow('PAYMENT_002');

    // Assert: DB pool 沒有被佔用
    const poolStatus = await db.getPoolStatus();
    return {
      actual: poolStatus.activeConnections,
      expected: 0,
      suggestion: '如果 > 0，檢查 PaymentServiceImpl 是否有 finally 釋放 connection',
    };
  });
});
