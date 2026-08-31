package cl.duoc.bancoxyzbatch.config;

import org.springframework.batch.core.job.Job;
import org.springframework.batch.core.job.parameters.JobParameters;
import org.springframework.batch.core.job.parameters.JobParametersBuilder;
import org.springframework.batch.core.launch.JobOperator;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Locale;

/**
 * Controlo qué Job se ejecuta y registro sus métricas principales.
 *
 * También distingo entre Jobs paralelos y secuenciales para que
 * las métricas impresas representen los hilos realmente utilizados.
 *
 * La configuración paralela por defecto utiliza 3 hilos y un
 * chunk-size de 10, valores seleccionados mediante benchmarks
 * controlados sobre el dataset actual.
 */
@Component
public class ControlledJobRunner
        implements ApplicationRunner {

    private final JobOperator jobOperator;
    private final List<Job> jobs;
    private final Environment environment;

    public ControlledJobRunner(
            JobOperator jobOperator,
            List<Job> jobs,
            Environment environment
    ) {
        this.jobOperator = jobOperator;
        this.jobs = jobs;
        this.environment = environment;
    }

    @Override
    public void run(
            ApplicationArguments args
    ) throws Exception {

        String requestedJob =
                environment.getProperty(
                        "app.batch.job"
                );

        /*
         * Si no se solicita un Job,
         * la aplicación inicia sin ejecutar procesos.
         */
        if (requestedJob == null
                || requestedJob.isBlank()) {

            System.out.println(
                    "[BATCH] Ningún Job solicitado."
            );

            return;
        }

        String runIdValue =
                environment.getProperty(
                        "app.batch.run-id"
                );

        if (runIdValue == null
                || runIdValue.isBlank()) {

            throw new IllegalArgumentException(
                    "Debe indicar "
                            + "--app.batch.run-id=<numero>"
            );
        }

        Long runId;

        try {

            runId =
                    Long.valueOf(
                            runIdValue
                    );

        } catch (NumberFormatException ex) {

            throw new IllegalArgumentException(
                    "app.batch.run-id debe ser "
                            + "un número entero.",
                    ex
            );
        }

        Job job =
                jobs.stream()
                        .filter(candidate ->
                                candidate.getName()
                                        .equals(
                                                requestedJob
                                        )
                        )
                        .findFirst()
                        .orElseThrow(() ->
                                new IllegalArgumentException(
                                        "Job no encontrado: "
                                                + requestedJob
                                                + ". Disponibles: "
                                                + obtenerJobsDisponibles()
                                )
                        );

        /*
         * El run.id genera una JobInstance distinta
         * y facilita las ejecuciones controladas.
         */
        JobParameters parameters =
                new JobParametersBuilder()
                        .addLong(
                                "run.id",
                                runId
                        )
                        .toJobParameters();

        /*
         * Cantidad global de hilos configurados.
         *
         * El valor por defecto de 3 corresponde al
         * resultado óptimo de los benchmarks realizados.
         */
        int configuredThreads =
                environment.getProperty(
                        "app.batch.threads",
                        Integer.class,
                        3
                );

        /*
         * cuentaInteresJob se ejecuta intencionalmente
         * de forma secuencial debido a la existencia de
         * múltiples registros con el mismo cuenta_id.
         *
         * Los demás Jobs mantienen procesamiento paralelo.
         */
        boolean parallelExecution =
                !"cuentaInteresJob".equals(
                        job.getName()
                );

        int effectiveThreads =
                parallelExecution
                        ? configuredThreads
                        : 1;

        String executionMode =
                parallelExecution
                        ? "PARALELO"
                        : "SECUENCIAL";

        /*
         * El chunk-size por defecto de 10 fue seleccionado
         * mediante pruebas comparativas de rendimiento
         * y estabilidad.
         */
        int chunkSize =
                environment.getProperty(
                        "app.batch.chunk-size",
                        Integer.class,
                        10
                );

        long retryMaxRetries =
                environment.getProperty(
                        "app.batch.retry-max-retries",
                        Long.class,
                        3L
                );

        int skipLimit =
                environment.getProperty(
                        "app.batch.skip-limit",
                        Integer.class,
                        750
                );

        System.out.println(
                "[BATCH] Ejecutando Job: "
                        + job.getName()
        );

        System.out.println(
                "[BATCH] run.id: "
                        + runId
        );

        System.out.println(
                "[BATCH-PERF] configuración"
                        + " | mode="
                        + executionMode
                        + " | threads="
                        + effectiveThreads
                        + " | chunkSize="
                        + chunkSize
                        + " | skipLimit="
                        + skipLimit
                        + " | retryMaxRetries="
                        + retryMaxRetries
        );

        /*
         * Mido la duración total del Job para
         * comparar posteriormente distintas configuraciones.
         */
        long inicioNs =
                System.nanoTime();

        var execution =
                jobOperator.start(
                        job,
                        parameters
                );

        long finNs =
                System.nanoTime();

        double duracionMs =
                (finNs - inicioNs)
                        / 1_000_000.0;

        System.out.println(
                "[BATCH] JobExecution ID: "
                        + execution.getId()
        );

        System.out.println(
                "[BATCH] Estado final: "
                        + execution.getStatus()
        );

        System.out.println(
                "[BATCH] Exit status: "
                        + execution.getExitStatus()
        );

        System.out.println(
                "[BATCH-PERF] job="
                        + job.getName()
                        + " | mode="
                        + executionMode
                        + " | threads="
                        + effectiveThreads
                        + " | chunkSize="
                        + chunkSize
                        + " | duraciónMs="
                        + String.format(
                                Locale.ROOT,
                                "%.3f",
                                duracionMs
                        )
        );
    }

    /**
     * Obtengo los nombres de los Jobs registrados
     * para generar mensajes de error más claros.
     */
    private String obtenerJobsDisponibles() {

        return jobs.stream()
                .map(candidate ->
                        candidate.getName()
                )
                .sorted()
                .toList()
                .toString();
    }
}
