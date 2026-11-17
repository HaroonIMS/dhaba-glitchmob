package dhaba.kitchen;

import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

import org.junit.jupiter.api.Test;
import org.mockito.InOrder;

class OrderProcessorTest {

    private final OrderRepository repo = mock(OrderRepository.class);
    private final OrderProcessor processor = new OrderProcessor(repo, 0);

    @Test
    void movesOrderFromCookingToReady() throws Exception {
        processor.process("42");

        InOrder order = inOrder(repo);
        order.verify(repo).updateStatus(42L, "cooking");
        order.verify(repo).updateStatus(42L, "ready");
    }

    @Test
    void ignoresJobsWithABadId() throws Exception {
        processor.process("not-a-number");

        verifyNoInteractions(repo);
    }
}
