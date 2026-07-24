require "rails_helper"

RSpec.describe ApplicationJob do
  # Throwaway job that always blows up, used to exercise the base-class error handling.
  let(:failing_job_class) do
    Class.new(described_class) do
      def perform = raise(StandardError, "boom")
    end
  end

  it "re-raises the error instead of swallowing it" do
    expect { failing_job_class.perform_now }.to raise_error(StandardError, "boom")
  end

  it "logs the failure before re-raising" do
    allow(Rails.logger).to receive(:error)

    expect { failing_job_class.perform_now }.to raise_error(StandardError)

    expect(Rails.logger).to have_received(:error).with(/Job failed:.*StandardError: boom/)
  end
end
