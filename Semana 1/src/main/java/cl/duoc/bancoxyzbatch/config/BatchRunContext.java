package cl.duoc.bancoxyzbatch.config;

import org.springframework.batch.core.configuration.annotation.StepScope;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
@StepScope
public class BatchRunContext {

    private final Long jobInstanceId;

    public BatchRunContext(
            @Value("#{stepExecution.jobExecution.jobInstance.id}")
            Long jobInstanceId
    ) {
        this.jobInstanceId = jobInstanceId;
    }

    public Long getJobInstanceId() {
        return jobInstanceId;
    }
}
