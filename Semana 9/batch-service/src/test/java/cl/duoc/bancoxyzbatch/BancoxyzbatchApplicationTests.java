package cl.duoc.bancoxyzbatch;

import org.junit.jupiter.api.Test;
import org.springframework.batch.core.job.Job;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest
class BancoxyzbatchApplicationTests {

	@Autowired
	private Map<String, Job> jobs;

	@Test
	void cargaLosTresProcesosBatchExigidosPorLaRubrica() {
		assertEquals(
				Set.of("transaccionJob", "cuentaInteresJob", "estadoCuentaAnualJob"),
				jobs.keySet()
		);
	}

}
