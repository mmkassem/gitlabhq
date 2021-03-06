# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Lint do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:lint) { described_class.new(project: project, current_user: user) }

  describe '#validate' do
    subject { lint.validate(content, dry_run: dry_run) }

    shared_examples 'content is valid' do
      let(:content) do
        <<~YAML
        build:
          stage: build
          before_script:
            - before_build
          script: echo
          environment: staging
          when: manual
        rspec:
          stage: test
          script: rspec
          after_script:
            - after_rspec
          tags: [docker]
        YAML
      end

      it 'returns a valid result', :aggregate_failures do
        expect(subject).to be_valid

        expect(subject.errors).to be_empty
        expect(subject.warnings).to be_empty
        expect(subject.jobs).to be_present

        build_job = subject.jobs.first
        expect(build_job[:name]).to eq('build')
        expect(build_job[:stage]).to eq('build')
        expect(build_job[:before_script]).to eq(['before_build'])
        expect(build_job[:script]).to eq(['echo'])
        expect(build_job.fetch(:after_script)).to be_nil
        expect(build_job[:tag_list]).to eq([])
        expect(build_job[:environment]).to eq('staging')
        expect(build_job[:when]).to eq('manual')
        expect(build_job[:allow_failure]).to eq(true)

        rspec_job = subject.jobs.last
        expect(rspec_job[:name]).to eq('rspec')
        expect(rspec_job[:stage]).to eq('test')
        expect(rspec_job.fetch(:before_script)).to be_nil
        expect(rspec_job[:script]).to eq(['rspec'])
        expect(rspec_job[:after_script]).to eq(['after_rspec'])
        expect(rspec_job[:tag_list]).to eq(['docker'])
        expect(rspec_job.fetch(:environment)).to be_nil
        expect(rspec_job[:when]).to eq('on_success')
        expect(rspec_job[:allow_failure]).to eq(false)
      end
    end

    shared_examples 'content with errors and warnings' do
      context 'when content has errors' do
        let(:content) do
          <<~YAML
          build:
            invalid: syntax
          YAML
        end

        it 'returns a result with errors' do
          expect(subject).not_to be_valid
          expect(subject.errors).to include(/root config contains unknown keys/)
        end
      end

      context 'when content has warnings' do
        let(:content) do
          <<~YAML
          rspec:
            script: rspec
            rules:
              - when: always
          YAML
        end

        it 'returns a result with warnings' do
          expect(subject).to be_valid
          expect(subject.warnings).to include(/rspec may allow multiple pipelines to run/)
        end
      end

      context 'when content has errors and warnings' do
        let(:content) do
          <<~YAML
          rspec:
            script: rspec
            rules:
              - when: always
          karma:
            script: karma
            unknown: key
          YAML
        end

        it 'returns a result with errors and warnings' do
          expect(subject).not_to be_valid
          expect(subject.errors).to include(/karma config contains unknown keys/)
          expect(subject.warnings).to include(/rspec may allow multiple pipelines to run/)
        end
      end
    end

    shared_context 'advanced validations' do
      let(:content) do
        <<~YAML
        build:
          stage: build
          script: echo
          rules:
            - if: '$CI_MERGE_REQUEST_ID'
        test:
          stage: test
          script: echo
          needs: [build]
        YAML
      end
    end

    context 'when user has permissions to write the ref' do
      before do
        project.add_developer(user)
      end

      context 'when using default static mode' do
        let(:dry_run) { false }

        it_behaves_like 'content with errors and warnings'

        it_behaves_like 'content is valid' do
          it 'includes extra attributes' do
            subject.jobs.each do |job|
              expect(job[:only]).to eq(refs: %w[branches tags])
              expect(job.fetch(:except)).to be_nil
            end
          end
        end

        include_context 'advanced validations' do
          it 'does not catch advanced logical errors' do
            expect(subject).to be_valid
            expect(subject.errors).to be_empty
          end
        end

        it 'uses YamlProcessor' do
          expect(Gitlab::Ci::YamlProcessor)
            .to receive(:new_with_validation_errors)
            .and_call_original

          subject
        end
      end

      context 'when using dry run mode' do
        let(:dry_run) { true }

        it_behaves_like 'content with errors and warnings'

        it_behaves_like 'content is valid' do
          it 'does not include extra attributes' do
            subject.jobs.each do |job|
              expect(job.key?(:only)).to be_falsey
              expect(job.key?(:except)).to be_falsey
            end
          end
        end

        include_context 'advanced validations' do
          it 'runs advanced logical validations' do
            expect(subject).not_to be_valid
            expect(subject.errors).to eq(["test: needs 'build'"])
          end
        end

        it 'uses Ci::CreatePipelineService' do
          expect(::Ci::CreatePipelineService)
            .to receive(:new)
            .and_call_original

          subject
        end
      end
    end

    context 'when user does not have permissions to write the ref' do
      before do
        project.add_reporter(user)
      end

      context 'when using default static mode' do
        let(:dry_run) { false }

        it_behaves_like 'content is valid'
      end

      context 'when using dry run mode' do
        let(:dry_run) { true }

        let(:content) do
          <<~YAML
          job:
            script: echo
          YAML
        end

        it 'does not allow validation' do
          expect(subject).not_to be_valid
          expect(subject.errors).to include('Insufficient permissions to create a new pipeline')
        end
      end
    end
  end
end
