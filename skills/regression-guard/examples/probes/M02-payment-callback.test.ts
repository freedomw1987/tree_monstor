/**
 * M02-payment-callback 探針範例
 *
 * 對應 skill：`regression-guard`（v2.10 加 Module prefix 規則）
 * 對應 US：M02-US-202（付款回呼更新訂單）
 * 對應 AC：AC-2 冪等性
 */

import { probe, describe } from 'regression-guard';

describe('M02-payment-callback', () => {

  probe('M02-payment-callback-is-idempotent', async () => {
    // Arrange
    const callback = {
      gatewayRef: 'ch_1234567890',
      status: 'succeeded',
      signature: 'valid_signature',
    };

    // Act: 同一個 callback 發 3 次
    await paymentService.handleCallback(callback);
    await paymentService.handleCallback(callback);
    const finalStatus = await paymentService.handleCallback(callback);

    // Assert: 第 2 / 3 次不應該重複處理（不應該 throw 也不應該重複扣款）
    return {
      actual: finalStatus,
      expected: 'SUCCESS',
      suggestion: '如果 finalStatus 是 FAILED，檢查 handleCallback 是否有冪等檢查（gatewayRef 唯一索引）',
    };
  });

  probe('M02-payment-callback-rejects-invalid-signature', async () => {
    // Arrange
    const callback = {
      gatewayRef: 'ch_1234567891',
      status: 'succeeded',
      signature: 'INVALID_SIGNATURE',
    };

    // Act + Assert
    try {
      await paymentService.handleCallback(callback);
      throw new Error('應該 reject 但沒有');
    } catch (err) {
      return {
        actual: err.code,
        expected: 'PAYMENT_005', // 假設定義的「無效簽名」錯誤碼
      };
    }
  });
});
