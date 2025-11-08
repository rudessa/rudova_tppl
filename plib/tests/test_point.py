from plib import Point
import pytest
import json
import sys
from pathlib import Path

# корневая директория проекта
sys.path.insert(0, str(Path(__file__).parent.parent))


@pytest.fixture
def points():
    return Point(0, 0), Point(2, 2)


class TestPoint:

    def test_creation(self):
        p = Point(1, 2)
        assert p.x == 1 and p.y == 2

        with pytest.raises(TypeError):
            Point(1.5, 1.5)

        with pytest.raises(TypeError):
            Point(1, 1.5)

        with pytest.raises(TypeError):
            Point(1.5, 1)

    def test_add(self, points):
        p1, p2 = points
        assert p2 + p1 == Point(2, 2)
        assert p1 + p2 == Point(2, 2)

    def test_iadd(self, points):
        p1, p2 = points
        p1 += p2
        assert p1 == Point(2, 2)

    def test_eq(self, points):
        p1, p2 = points
        assert p1 == Point(0, 0)
        assert not (p1 == p2)

        # NotImplementedError при сравнении с не-Point объектом
        with pytest.raises(NotImplementedError):
            p1 == "not a point"

        with pytest.raises(NotImplementedError):
            p1 == 5

    def test_sub(self, points):
        p1, p2 = points
        assert p2 - p1 == Point(2, 2)
        assert p1 - p2 == -Point(2, 2)

    def test_neg(self):
        p = Point(3, 4)
        neg_p = -p
        assert neg_p == Point(-3, -4)

        p_zero = Point(0, 0)
        assert -p_zero == Point(0, 0)

    def test_distance_to(self):
        p1 = Point(0, 0)
        p2 = Point(2, 0)
        assert p1.to(p2) == 2

    @pytest.mark.parametrize(
        "p1, p2, distance",
        [(Point(0, 0), Point(0, 10), 10),
         (Point(0, 0), Point(10, 0), 10),
         (Point(0, 0), Point(1, 1), 1.414)]
    )
    def test_distance_all_axis(self, p1, p2, distance):
        assert p1.to(p2) == pytest.approx(distance, 0.001)

    def test_str(self):
        p = Point(5, 7)
        assert str(p) == "Point(5, 7)"

    def test_repr(self):
        p = Point(5, 7)
        assert repr(p) == "Point(5, 7)"

    def test_is_center(self, points):
        p1, p2 = points
        assert p1.is_center() == True
        assert p2.is_center() == False

        p3 = Point(0, 5)
        assert p3.is_center() == False

        p4 = Point(5, 0)
        assert p4.is_center() == False

    def test_to_json(self):
        p = Point(3, 4)
        json_str = p.to_json()
        assert json_str == '{"x": 3, "y": 4}'

        # Валидный JSON?
        parsed = json.loads(json_str)
        assert parsed["x"] == 3
        assert parsed["y"] == 4

    def test_from_json(self):
        json_str = '{"x": 10, "y": 20}'
        p = Point.from_json(json_str)
        assert p.x == 10
        assert p.y == 20
        assert isinstance(p, Point)

        # Тест круговой сериализации
        p1 = Point(15, 25)
        json_str = p1.to_json()
        p2 = Point.from_json(json_str)
        assert p1 == p2
