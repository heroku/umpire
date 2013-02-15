module Umpire
    module Aggregator
        class Avg
            def aggregate(points)
                points.inject { |sum, item| sum + item }.to_f / points.size
            end
        end

        class Sum
            def aggregate(points)
                points.inject { |sum, item| sum + item }.to_f
            end
        end

        class Min
            def aggregate(points)
                points.min.to_f
            end
        end

        class Max
            def aggregate(points)
                points.max.to_f
            end
        end
    end
end
