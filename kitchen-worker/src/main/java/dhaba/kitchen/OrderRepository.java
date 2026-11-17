package dhaba.kitchen;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Updates order statuses in Postgres. */
@Repository
public class OrderRepository {

    private final JdbcTemplate jdbc;

    public OrderRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public boolean updateStatus(long id, String status) {
        return jdbc.update("UPDATE orders SET status = ? WHERE id = ?", status, id) == 1;
    }
}
