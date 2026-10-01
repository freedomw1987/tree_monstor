/**
 * INT-M01-M02-checkout 整合測試探針範例
 *
 * 本檔為跨 Module 整合測試範例。
 *
 * 對應 skill：`regression-guard`（v2.10 INT- prefix 規則）
 * 對應 US：INT-M01-M02-01（登入後付款完整流程）
 *
 * 重要：跨 Module 整合測試必須明確標 `INT-` prefix，避免和 Module 內部探針混淆。
 */

import { probe, describe } from 'regression-guard';

describe('INT-M01-M02-checkout', () => {

  probe('INT-M01-M02-checkout-full-flow', async () => {
    // Arrange: 用戶已登入 + 購物車有商品
    const user = await userAuthService.login({
      email: 'test@example.com',
      password: 'valid_password',
    });
    await cartService.addItem(user.id, { productId: 'P001', quantity: 1 });

    // Act: 進入結帳 + 完成付款
    const checkout = await checkoutService.start(user.id);
    await paymentService.createPayment({
      orderId: checkout.orderId,
      amount: checkout.total,
      cardNumber: '4242424242424242',
    });

    // 模擬第三方回呼
    await paymentService.handleCallback({
      gatewayRef: 'ch_9999',
      status: 'succeeded',
      signature: 'valid',
    });

    // Assert: 訂單狀態變 PAID + 購物車清空
    const order = await orderService.getOrder(checkout.orderId);
    const cart = await cartService.getCart(user.id);

    return {
      actual: {
        orderStatus: order.status,
        cartItemCount: cart.items.length,
      },
      expected: {
        orderStatus: 'PAID',
        cartItemCount: 0,
      },
      suggestion: '如果 orderStatus 不是 PAID，檢查 event bus（M02 → M03）是否有正確 emit payment.success',
    };
  });
});
